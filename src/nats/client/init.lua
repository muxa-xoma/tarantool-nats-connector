local log = require('log')
local math = require('math')
local fiber = require('fiber')

local Errors = require('nats.utils.errors')
local Server = require('nats.client.server')
local Subscription = require('nats.client.subscription')
local Message = require('nats.client.message')
local Protocol = require('nats.protocol')
local Nuid = require('nats.utils.nuid')
local Transport = require('nats.transport')


math.randomseed(os.time())

---@type table<string, number>
local status = {
    disconnected = 0,
    connected = 1,
    closed = 2,
    reconnecting = 3,
    connecting = 4,
    draining_subs = 5,
    draining_pubs = 6
}

---@param err Error
---@return void
local function default_error_callback(err)
    if type(err) == 'table' then
        log.error('%s [%s]: %s', err.type, err.code, err.message)
    else
        log.error(err)
    end
end

---@class NatsClientOptions
---@field error_cb function Callback to report errors
---@field disconnected_cb function|nil Callback to report disconnection from NATS
---@field closed_cb function|nil Callback to report when client stops reconnection to NATS
---@field discovered_server_cb function|nil Callback to report when a new server joins the cluster
---@field reconnected_cb function|nil Callback to report when client reconnected to server
---@field name string|nil Label the connection with name (shown in NATS monitoring)
---@field pedantic boolean|nil Turns on additional strict format checking, e.g. for properly formed subjects
---@field verbose boolean|nil Turns on +OK protocol acknowledgements
---@field allow_reconnect boolean Ability to reconnect to servers
---@field connect_timeout number Server connection timeout
---@field reconnect_time_wait number Wait time between reconnects
---@field max_reconnect_attempts number Maximum number of reconnection attempts
---@field ping_interval number Interval between sending pings to the server
---@field max_outstanding_pings number Maximum number of failed pings
---@field dont_randomize boolean Do not mix servers in the pool
---@field no_echo boolean|nil Disabling the echo parameter
---@field user string|nil User to connect to the server
---@field password string|nil Password to connect to the server
---@field drain_timeout number Waiting for a graceful disconnect from the server
---@field inbox_prefix string Prefix for random topics
---@field pending_size number Max size of the pending buffer for publishing commands
---@field flush_timeout number
---@field flusher_queue_size number
local default_options = {
    error_cb = default_error_callback,
    allow_reconnect = true,
    connect_timeout = 2,
    reconnect_time_wait = 2,
    max_reconnect_attempts = 60,
    ping_interval = 120,
    max_outstanding_pings = 2,
    dont_randomize = false,
    no_echo = false,
    drain_timeout = 30,
    inbox_prefix = '_INBOX',
    pending_size = 2 * 1024 * 1024,
    flush_timeout = 10,
    flusher_queue_size = 1024
}

---@class NatsClient class representing a connection to NATS
---@field private _server_pool NatsServer[]
---@field private _cb table<string, function> callback functions
---@field private _connection_params NatsConnectionParameters server connection parameters
---@field private _params table<string, boolean|number|string> client parameters
---@field private _status number client status
---@field private _nuid Nuid instance class Nuid
---@field private _command NatsClientCommand instance class NatsClientCommand
---@field private _parser NatsParser instance class NatsParser
---@field private _transport TCPTransport instance class TCPTransport
---@field private _error Error last error
---@field private _current_server NatsServer server to which the connection is made
---@field private _setup_server_pool function parses and sets up a server pool
---@field private _setup_client_options function checking and installing client configuration
---@field private _select_next_server function select next server to connect
---@field private _process_info function processing info type message
---@field private _process_connect_init function establishes a connection with the server
---@field public new function returns an instance of the class
---@field public connected_url function returns connected url
---@field public servers function returns all servers
---@field public discovered_servers function returns discovered servers
---@field public max_payload function returns max payload in info message
---@field public client_id function returns client id in info message
---@field public last_error function returns last error
---@field public is_closed function returns true then client state closed
---@field public is_reconnecting function returns true then client state connecting
---@field public is_connected function returns true then client state connected
---@field public is_connecting function returns true then client state connecting
---@field public is_draining function returns true then client state draining pubs or draining subs
---@field public is_draining_pubs function returns true then client state draining pubs
---@field public connected_server_version function returns he Version of the server to which the client is currently connected
local M = {}
M.__index = M

-- setup --

---@param servers string|table connection string or connection strings list
---@param options NatsConnectionParameters|nil connection parameters
---@return NatsClient
function M.new(servers, options)
    ---@type NatsClient
    local self = setmetatable({}, M)
    self:_setup_server_pool(servers)
    self:_setup_client_options(options)
    self._status = status.disconnected
    self._nuid = Nuid.new()
    self._command = Protocol.command.new()
    self._parser = Protocol.parser.new()
    self._flush_queue = fiber.channel(self._params.flusher_queue_size)
    self._pending = ''
    self._sid = 0
    self._subs = {}
    self._resp_map = {}
    self._pongs = {}
    self._pings_outstanding = 0
    self._pongs_received = 0
    self._pending_data_size = 0
    self.stats = {
        in_msgs = 0,
        out_msgs = 0,
        in_bytes = 0,
        out_bytes = 0,
        reconnects = 0,
        errors_received = 0
    }
    while true do
        local ok, err = pcall(self._select_next_server, self)
        if not ok then
            self._error = err
            error(err)
        end
        ok, err = pcall(self._process_connect_init, self)
        if not ok then
            self._error = err
            self._cb.error_cb(err)
            if not self._params.allow_reconnect then
                error(err)
            end
            self:_close(status.disconnected, false)
            if self._current_server ~= nil then
                self._current_server.last_attempt = fiber.clock()
                self._current_server.reconnects = self._current_server.reconnects + 1
            end
        else
            assert(self._current_server, "the current server must be set by _select_next_server")
            self._current_server.reconnects = 0
            break
        end
    end
    return self
end

---@param self NatsClient class instance
---@param servers string|table connection string or connection strings list
---@return void
function M._setup_server_pool(self, servers)
    if type(servers) ~= 'string' and type(servers) ~= 'table' then
        error(Errors.invalid_connect_params)
    end
    self._server_pool = {}
    if type(servers) == 'string' then
        table.insert(self._server_pool, Server.new(servers))
    else
        for _, v in ipairs(servers) do
            if type(v) ~= 'string' then
                error(Errors.invalid_connect_params)
            end
            table.insert(self._server_pool, Server.new(v))
        end
    end
end

---@param self NatsClient class instance
---@param options NatsClientOptions connection parameters
---@return void
function M._setup_client_options(self, options)
    if options ~= nil and type(options) ~= 'table' then
        error(Errors.invalid_connect_params)
    end
    self._cb = {}
    if options and type(options.error_cb) ~= 'function' then
        error(Errors.invalid_connect_params)
    else
        self._cb.error_cb = options and options.error_cb or default_options.error_cb
    end
    if options and options.disconnected_cb ~= nil and type(options.disconnected_cb) ~= 'function' then
        error(Errors.invalid_connect_params)
    else
        self._cb.disconnected_cb = options and options.disconnected_cb or default_options.disconnected_cb
    end
    if options and options.closed_cb ~= nil and type(options.closed_cb) ~= 'function' then
        error(Errors.invalid_connect_params)
    else
        self._cb.closed_cb = options and options.closed_cb or default_options.closed_cb
    end
    if options and options.discovered_server_cb ~= nil and type(options.discovered_server_cb) ~= 'function' then
        error(Errors.invalid_connect_params)
    else
        self._cb.discovered_server_cb = options and options.discovered_server_cb or default_options.discovered_server_cb
    end
    if options and options.reconnected_cb ~= nil and type(options.reconnected_cb) ~= 'function' then
        error(Errors.invalid_connect_params)
    else
        self._cb.reconnected_cb = options and options.reconnected_cb or default_options.reconnected_cb
    end
    if options and options.name ~= nil and type(options.name) ~= 'string' then
        error(Errors.invalid_connect_params)
    end
    if options and options.user ~= nil and type(options.user) ~= 'string' then
        error(Errors.invalid_connect_params)
    end
    if options and options.password ~= nil and type(options.password) ~= 'string' then
        error(Errors.invalid_connect_params)
    end
    if options and options.no_echo ~= nil and type(options.no_echo) ~= 'boolean' then
        error(Errors.invalid_connect_params)
    end
    if options and options.pedantic ~= nil and type(options.pedantic) ~= 'boolean' then
        error(Errors.invalid_connect_params)
    end
    if options and options.verbose ~= nil and type(options.verbose) ~= 'boolean' then
        error(Errors.invalid_connect_params)
    end
    self._connection_params = Protocol.con_params.new(
            options and options.name or default_options.name,
            options and options.user or default_options.user,
            options and options.password or default_options.password,
            nil,
            nil,
            nil,
            not (options and options.no_echo or default_options.no_echo),
            nil,
            options and options.verbose or default_options.verbose,
            options and options.pedantic or default_options.pedantic,
            nil
    )
    self._params = {}
    if options and options.allow_reconnect ~= nil and type(options.allow_reconnect) ~= 'boolean' then
        error(Errors.invalid_connect_params)
    else
        self._params.allow_reconnect = options and options.allow_reconnect or default_options.allow_reconnect
    end
    if options and options.connect_timeout ~= nil and type(options.connect_timeout) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.connect_timeout = options and options.connect_timeout or default_options.connect_timeout
    end
    if options and options.reconnect_time_wait ~= nil and type(options.reconnect_time_wait) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.reconnect_time_wait = options and options.reconnect_time_wait or default_options.reconnect_time_wait
    end
    if options and options.max_reconnect_attempts ~= nil and type(options.max_reconnect_attempts) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.max_reconnect_attempts = options and options.max_reconnect_attempts or default_options.max_reconnect_attempts
    end
    if options and options.ping_interval ~= nil and type(options.ping_interval) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.ping_interval = options and options.ping_interval or default_options.ping_interval
    end
    if options and options.max_outstanding_pings ~= nil and type(options.max_outstanding_pings) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.max_outstanding_pings = options and options.max_outstanding_pings or default_options.max_outstanding_pings
    end
    if options and options.drain_timeout ~= nil and type(options.drain_timeout) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.drain_timeout = options and options.drain_timeout or default_options.drain_timeout
    end
    if options and options.inbox_prefix ~= nil and type(options.inbox_prefix) ~= 'string' then
        error(Errors.invalid_connect_params)
    else
        self._params.inbox_prefix = options and options.inbox_prefix or default_options.inbox_prefix
    end
    if options and options.pending_size ~= nil and type(options.pending_size) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.pending_size = options and options.pending_size or default_options.pending_size
    end
    if options and options.flush_timeout ~= nil and type(options.flush_timeout) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.flush_timeout = options and options.flush_timeout or default_options.flush_timeout
    end
    if options and options.flusher_queue_size ~= nil and type(options.flusher_queue_size) ~= 'number' then
        error(Errors.invalid_connect_params)
    else
        self._params.flusher_queue_size = options and options.flusher_queue_size or default_options.flusher_queue_size
    end
    local dont_randomize
    if options and options.dont_randomize ~= nil then
        dont_randomize = options.dont_randomize
    else
        dont_randomize = default_options.dont_randomize
    end
    self._params.dont_randomize = dont_randomize
    if #self._server_pool > 1 and not self._params.dont_randomize then
        table.sort(self._server_pool, function (_, _) return math.random(1, 2) == 1 end)
    end
end

-- setup --

-- closed --

---@param self NatsClient class instance
---@return void
function M.close(self)
    self:_close(status.closed)
end

---@param self NatsClient class instance
---@param status_n number the status with which the connection will be closed
---@param do_cbs boolean the need to call callback functions
---@return void
function M._close(self, status_n, do_cbs)
    if self:is_closed() then
        self._status = status_n
        return
    end
    self._status = status.closed
    self:_flush_pending()
    if self._reading_task ~= nil and self._reading_task:status() ~= 'dead' then
        self._reading_task:cancel()
    end
    if self._ping_interval_task ~= nil and self._ping_interval_task:status() ~= 'dead' then
        self._ping_interval_task:cancel()
    end
    if self._flusher_task ~= nil and self._flusher_task:status() ~= 'dead' then
        self._flusher_task:cancel()
    end
    if self._reconnection_task ~= nil and self._reconnection_task:status() ~= 'dead' then
        self._reconnection_task:cancel()
        if self._reconnection_task_future ~= nil and self._reconnection_task_future:status() ~= 'dead' then
            self._reconnection_task_future:join(self._params.reconnect_time_wait)
        end
    end
    fiber.yield()
    if self._current_server ~= nil and self._transport ~= nil then
        if self._pending_data_size > 0 then
            self._transport:write(self._pending)
            self._pending_data_size = 0
            self._pending = ''
        end
    end
    for _, v in pairs(self._subs) do
        v:drain()
    end
    if self._transport ~= nil then
        local result = self._transport:close()
        if not result.success then
            self._cb.error_cb(result.error)
        end
    end
    if do_cbs then
        if self._cb.disconnected_cb ~= nil then
            self._cb.disconnected_cb()
        end
        if self._cb.closed_cb ~= nil then
            self._cb.closed_cb()
        end
    end
end

---@param self NatsClient class instance
---@return void
function M.drain(self)
    if self:is_draining() then
        return
    end
    if self:is_closed() then
        error(Errors.connection_closed)
    end
    if self:is_connecting() or self:is_reconnecting() then
        error(Errors.connection_reconnecting)
    end
    local drain_tasks = {}
    for _, v in pairs(self._subs) do
        local task = fiber.new(v._drain, v)
        table.insert(drain_tasks, task)
    end
    fiber.yield()
    self._status = status.draining_subs
    local start_t = fiber.clock()
    while #drain_tasks > 0 and fiber.clock() < start_t + self._params.drain_timeout do
        for n, v in ipairs(drain_tasks) do
            if v:status() == 'dead' then
                table.remove(drain_tasks, n)
            end
        end
        fiber.yield()
    end
    if #drain_tasks > 0 then
        self._cb.error_cb(Errors.drain_timeout)
    end
    self._status = status.draining_pubs
    self:flush()
    self._close(status.closed)
end

-- closed --

-- flusher --

---@param self NatsClient class instance
---@param force_flush boolean wait for an answer
---@return void
function M._flush_pending(self, force_flush)
    assert(self._flush_queue, 'must be called only from Client.new')
    local future
    if force_flush then
        future = fiber.channel(1)
    else
        future = 'future'
    end
    if not self:is_connected() then
        future:put(false)
        return future
    end
    self._flush_queue:put(future)
    if force_flush then
        local result = future:get(self._params.flush_timeout)
        future:close()
        if result == nil then
            error(Errors.flush_timeout)
        end
    end
end

---@param self NatsClient class instance
---@return void
function M._flusher(self)
    assert(self._transport, 'must be called only from Client.new')
    assert(self._flush_queue, 'must be called only from Client.new')
    while true do
        fiber.yield()
        if not self:is_connected() or self:is_connecting() then
            break
        end
        local future = self._flush_queue:get()
        if self._pending_data_size > 0 then
            local result = self._transport:write(self._pending)
            if not result.success then
                self._cb.error_cb(result.error)
                fiber.new(self._process_op_err, self, result.error)
                self._flush_queue:put(future)
                break
            else
                self._pending = ''
                self._pending_data_size = 0
            end
        end
        if type(future) ~= 'string' then
            future:put(true)
        end
    end
end

---@param self NatsClient class instance
---@param future userdata fiber.channel
---@return void
function M._send_ping(self, future)
    assert(self._transport, 'must be called only from Client.new')
    if future == nil then
        future = 'future'
    end
    table.insert(self._pongs, future)
    local result = self._transport:write(self._command:ping())
    if not result.success then
        self._cb.error_cb(result.error)
    else
        self._pending_data_size = self._pending_data_size + result.data
        self:_flush_pending()
    end
end

---@param self NatsClient class instance
---@param timeout number wait timeout
---@return void
function M.flush(self, timeout)
    timeout = timeout or self._params.flush_timeout
    if timeout <= 0 then
        error(Errors.bad_timeout)
    end
    if self:is_closed() then
        error(Errors.connection_closed)
    end
    local future = fiber.channel(1)
    fiber.new(self._send_ping, self, future)
    local result = future:get(timeout)
    future:close()
    if result == nil then
        error(Errors.flush_timeout)
    end
end

-- flusher --

-- commands --

---@param self NatsClient class instance
---@param cmd string command
---@param priority boolean whether to send the command first
---@return void
function M._send_command(self, cmd, priority)
    local cmd_t = {self._pending, cmd}
    if priority then
        cmd_t = {cmd, self._pending}
    end
    self._pending = table.concat(cmd_t)
    self._pending_data_size = self._pending_data_size + #cmd
    if self._params.pending_size > 0 and self._pending_data_size > self._params.pending_size then
        self:_flush_pending(true)
    end
end

---@param self NatsClient class instance
---@param subject string subject of dispatch
---@param reply string subject of receiving the response
---@param payload string message
---@param payload_size number size message
---@param headers table<string, string> headers
---@return void
function M._send_publish(self, subject, reply, payload, payload_size, headers)
    if subject == '' then
        error(Errors.bad_subject)
    end
    local cmd
    if headers ~= nil then
        cmd = self._command:headers_publish(subject, payload, headers, reply)
    else
        cmd = self._command:publish(subject, payload, reply)
    end
    self.stats.out_msgs = self.stats.out_msgs + 1
    self.stats.out_bytes = self.stats.out_bytes + payload_size
    self:_send_command(cmd)
    if self._flush_queue ~= nil and self._flush_queue:is_empty() then
        self:_flush_pending()
    end
end

---@param self NatsClient class instance
---@param subject string subject of dispatch
---@param reply string subject of receiving the response
---@param payload string message
---@param headers table<string, string> headers
---@return void
function M.publish(self, subject, payload, reply, headers)
    if self:is_closed() then
        error(Errors.connection_closed)
    end
    if self:is_draining_pubs() then
        error(Errors.connection_draining)
    end
    local payload_size = #payload
    if not self:is_connected() then
        if self._params.pending_size <= 0 or (payload_size + self._pending_data_size > self._params.pending_size) then
            error(Errors.outbound_buffer_limit)
        end
    end
    if payload_size > self._current_server.info.max_payload then
        error(Errors.max_payload)
    end
    self:_send_publish(subject, reply, payload, payload_size, headers)
end

---@param self NatsClient class instance
---@param sid number subscription id
---@return void
function M._remove_sub(self, sid)
    self._subs[tostring(sid)] = nil
end

---@param self NatsClient class instance
---@param subscription Subscription class instance
---@return void
function M._send_subscribe(self, subscription)
    self:_send_command(self._command:subscribe(subscription._subject, subscription._id, subscription._queue))
    self:_flush_pending()
end

---@param self NatsClient class instance
---@param subject string subscription subject
---@param queue string|nil subscription queue
---@param cb function|nil callback function
---@param max_msgs number|nil maximum number of messages expected from a subscription
---@param pending_msgs_limit number|nil maximum number of messages in the handler queue
---@param pending_bytes_limit number|nil maximum number of bytes in the handler queue
---@return Subscription class instance
function M.subscribe(self, subject, queue, cb, max_msgs, pending_msgs_limit, pending_bytes_limit)
    if subject == nil or string.find(subject, ' ') ~= nil then
        error(Errors.bad_subject)
    end
    if queue ~= nil and string.find(queue, ' ') ~= nil then
        error(Errors.bad_subject)
    end
    if self:is_closed() then
        error(Errors.connection_closed)
    end
    if self:is_draining() then
        error(Errors.connection_draining)
    end
    self._sid = self._sid + 1
    local sid = self._sid
    local sub = Subscription.new(self, sid, subject, queue, cb, max_msgs, pending_msgs_limit, pending_bytes_limit)
    sub:_start()
    self._subs[tostring(sid)] = sub
    self:_send_subscribe(sub)
    return sub
end

---@param self NatsClient class instance
---@param sid number subscription id
---@param limit number number of messages expected from subscription
---@return void
function M._send_unsubscribe(self, sid, limit)
    self:_send_command(self._command:unsubscribe(sid, limit))
    self:_flush_pending()
end

---@param self NatsClient class instance
---@return string
function M.new_inbox(self)
    return table.concat({ self._params.inbox_prefix, self._nuid:next() }, '.')
end

---@param msg Message returned message
---@return void
function M._request_sub_callback(msg)
    local future = msg._client._resp_map[msg.subject]
    if future == nil then
        return
    end
    future:put(msg)
end

---@param self NatsClient class instance
---@param subject string subject from which the message came
---@param payload string message payload
---@param headers table<string, string>|nil message headers
---@param timeout number|nil response timeout
---@return Message
function M._request(self, subject, payload, headers, timeout)
    if self:is_draining_pubs() then
        error(Errors.connection_draining)
    end
    local future = fiber.channel(1)
    local resp_subject = self:new_inbox()
    self._resp_map[resp_subject] = future
    self:subscribe(resp_subject, nil, self._request_sub_callback)
    self:publish(subject, payload, resp_subject, headers)
    local result = future:get(timeout)
    future:close()
    if result == nil then
        error(Errors.timeout)
    end
    return result
end

---@param self NatsClient class instance
---@param subject string subject from which the message came
---@param payload string message payload
---@param headers table<string, string>|nil message headers
---@param timeout number|nil response timeout
---@return Message
function M.request(self, subject, payload, headers, timeout)
    timeout = timeout or 0.5
    return self:_request(subject, payload, headers, timeout)
end

-- commands --

-- processes --

---@param self NatsClient class instance
---@return void
function M._select_next_server(self)
    while true do
        if #self._server_pool == 0 then
            self._current_server = nil
            error(Errors.no_servers)
        end
        local now = fiber.clock()
        ---@type NatsServer
        local serv = table.remove(self._server_pool, 1)
        if self._params.max_reconnect_attempts > 0 then
            if (self._params.max_reconnect_attempts - serv.reconnects) > 1 then
                table.insert(self._server_pool, serv)
            end
        end
        if serv.last_attempt ~= nil and now < serv.last_attempt + self._params.reconnect_time_wait then
            fiber.sleep(self._params.reconnect_time_wait)
        end
        serv.last_attempt = fiber.clock()
        if self._transport == nil then
            -- TODO: Make a choice between TCP or WebSocket
            self._transport = Transport.tcp.new(serv.uri.host, serv.uri.service, self._params.connect_timeout)
        end
        -- TODO: tls connection
        local result = self._transport:connect()
        if result.success then
            self._current_server = serv
            break
        else
            serv.last_attempt = fiber.clock()
            serv.reconnects = serv.reconnects + 1
            self._error = result.error
            self._cb.error_cb(result.error)
        end
    end
end

---@param self NatsClient class instance
---@param info_string string json string with server information
---@param initial_connection boolean is this the first attempt to connect
---@return void
function M._process_info(self, info_string, initial_connection)
    assert(self._current_server, "Client.new must be called first")
    assert(self._connection_params, "Client.new must be called first")
    if initial_connection == nil then
        initial_connection = false
    end
    self._current_server:set_server_info(info_string)
    local result = self._connection_params:set_server_info_params(self._current_server.info)
    if not result.success then
        error(result.error)
    end
    if self._current_server.info.connect_urls and #self._current_server.info.connect_urls > 0 then
        local connect_urls = {}
        for _, v in ipairs(self._current_server.info.connect_urls) do
            -- TODO: checking tls
            local serv = Server.new(v)
            serv:server_discovered()
            -- TODO: setup tls_name
            local should_add = true
            for _, s in ipairs(self._server_pool) do
                if serv.uri.host == s.uri.host then
                    should_add = false
                end
            end
            if should_add then
                table.insert(connect_urls, serv)
            end
        end
        if #connect_urls > 1 and not self._params.dont_randomize then
            table.sort(connect_urls, function (_, _) return math.random(1, 2) == 1 end)
        end
        for _, v in ipairs(connect_urls) do
            table.insert(self._server_pool, v)
        end
        if not initial_connection and connect_urls and self._cb.discovered_server_cb ~= nil then
            self._cb.discovered_server_cb()
        end
    end
end

---@param self NatsClient class instance
---@return void
function M._attempt_reconnect(self)
    assert(self._current_server, 'must be called only from Client.new')
    if self._reading_task ~= nil and self._reading_task:status() ~= 'dead' then
        self._reading_task:cancel()
    end
    if self._ping_interval_task ~= nil and self._ping_interval_task:status() ~= 'dead' then
        self._ping_interval_task:cancel()
    end
    if self._flusher_task ~= nil and self._flusher_task:status() ~= 'dead' then
        self._flusher_task:cancel()
    end
    if self._transport ~= nil then
        local result = self._transport:close()
        if not result.success then
            self._cb.error_cb(result.error)
        end
    end
    self._error = nil
    if self._cb.disconnected_cb ~= nil then
        self._cb.disconnected_cb()
    end
    if self:is_closed() then
        return
    end
    if not self._params.dont_randomize then
        table.sort(self._server_pool, function (_, _) return math.random(1, 2) == 1 end)
    end
    self._reconnection_task_future = fiber.new(
            function()
                while true do
                    local ok, err = pcall(self._select_next_server, self)
                    if not ok then
                        self._error = err
                        self:close()
                        break
                    end
                    assert(self._transport, '_select_next_server must set _transport')
                    ok, err = pcall(self._process_connect_init, self)
                    if not ok then
                        self._error = err
                        self._cb.error_cb(err)
                        self._status = status.reconnecting
                        self._current_server.last_attempt = fiber.clock()
                        self._current_server.reconnects = self._current_server.reconnects + 1
                    else
                        self.stats.reconnects = self.stats.reconnects + 1
                        self._current_server:need_connecting()
                        self._current_server.reconnects = 0
                        local subs_to_remove = {}
                        ---@param v Subscription
                        for k, v in pairs(self._subs) do
                            local max_msgs = 0
                            local is_continue = true
                            if v._max_msgs > 0 then
                                if v._received >= v._max_msgs then
                                    table.insert(subs_to_remove, k)
                                    is_continue = false
                                else
                                    max_msgs = v._max_msgs - v._received
                                end
                            end
                            if is_continue then
                                local result = self._transport:write(self._command:subscribe(v._subject, v._id, v._queue))
                                if not result.success then
                                    self._cb.error_cb(result.error)
                                    self._error = result.error
                                end
                                if max_msgs > 0 then
                                    result = self._transport:write(self._command:unsubscribe(k, max_msgs))
                                    if not result.success then
                                        self._cb.error_cb(result.error)
                                        self._error = result.error
                                    end
                                end
                            end
                        end
                        for _, v in ipairs(subs_to_remove) do
                            self._subs[v] = nil
                        end
                        self:_flush_pending()
                        self._status = status.connected
                        self:flush()
                        if self._cb.reconnected_cb ~= nil then
                            self._cb.reconnected_cb()
                        end
                        self._reconnection_task_future = nil
                        break
                    end
                end
            end
    )
    self._reconnection_task_future:set_joinable(true)
    fiber.yield()
    self._reconnection_task_future:join()
end

---@param self NatsClient class instance
---@return void
function M._process_disconnect(self)
    self._status = status.disconnected
end

---@param self NatsClient class instance
---@param err Error error message
---@return void
function M._process_op_err(self, err)
    if self:is_connecting() or self:is_closed() or self:is_reconnecting() then
        return
    end
    if self._params.allow_reconnect and self:is_connected() then
        self._status = status.reconnecting
        self._parser:_reset()
        if self._reconnection_task ~= nil and self._reconnection_task:status() ~= 'dead' then
            self._reconnection_task:cancel()
        end
        self._reconnection_task = fiber.new(self._attempt_reconnect, self)
    else
        self:_process_disconnect()
        self._error = err
        self:_close(status.closed, true)
    end
end

---@param self NatsClient class instance
---@return void
function M._process_connect_init(self)
    assert(self._transport, 'must be called only from Client.new')
    assert(self._current_server, 'must be called only from Client.new')
    self._status = status.connecting
    local read_result = self._transport:read()
    if not read_result.success then
        error(read_result.error)
    end
    local read_data = self._parser:parse(read_result.data)
    if not read_data.success then
        error(read_data.error)
    end
    if read_data.data.type == Protocol.constants.ping then
        self._transport:write(self._command:pong())
        read_result = self._transport:read()
        if not read_result.success then
            error(read_result.error)
        end
        read_data = self._parser:parse(read_result.data)
        if not read_data.success then
            error(read_data.error)
        end
    end
    if read_data.data.type ~= Protocol.constants.info then
        error(Errors.connection_not_info_msg)
    end
    self:_process_info(read_data.data.payload, true)
    if self:is_reconnecting() then
        self._parser:_reset()
    end
    assert(self._transport)
    local param = self._connection_params:tostring()
    if not param.success then
        error(param.error)
    end
    self._transport:write(self._command:connect(param.data))
    if self._connection_params.verbose then
        read_result = self._transport:read()
        if not read_result.success then
            error(read_result.error)
        end
        read_data = self._parser:parse(read_result.data)
        if not read_data.success then
            error(read_data.error)
        end
        if read_data.data.type == Protocol.constants.err then
            error(self._parser.error_parse(read_data.data.payload))
        end
    end
    self._transport:write(self._command:ping())
    read_result = self._transport:read()
    if not read_result.success then
        error(read_result.error)
    end
    read_data = self._parser:parse(read_result.data)
    if not read_data.success then
        error(read_data.error)
    end
    if read_data.data.type == Protocol.constants.pong then
        self._status = status.connected
    elseif read_data.data.type == Protocol.constants.err then
        error(self._parser.error_parse(read_data.data.payload))
    end
    self._reading_task = fiber.new(self._read_loop, self)
    self._pongs = {}
    self._pings_outstanding = 0
    self._ping_interval_task = fiber.new(self._ping_interval, self)
    self._flusher_task = fiber.new(self._flusher, self)
end

---@param self NatsClient class instance
---@return void
function M._ping_interval(self)
    while true do
        fiber.sleep(self._params.ping_interval)
        if self:is_connected() then
            self._pings_outstanding = self._pings_outstanding + 1
            if self._pings_outstanding > self._params.max_outstanding_pings then
                self:_process_op_err(Errors.stale_connection)
                return
            end
            self:_send_ping()
        end
    end
end

---@param self NatsClient class instance
---@param err Error error
---@return void
function M._process_err(self, err)
    self._error = err
    if err.code == Errors.stale_connection_serv.code then
        self:_process_op_err(Errors.stale_connection_serv)
        return
    end
    if (err.code > Errors.unk_protocol_err.code and err.code <= Errors.max_payload_serv.code) or err.code == Errors.unexpected_serv.code then
        local do_cbs = false
        if not self:is_connecting() then
            do_cbs = true
        end
        fiber.new(self._close, self, status.closed, do_cbs)
    end
end

---@param self NatsClient class instance
---@return void
function M._process_ping(self)
    self:_send_command(self._command:pong())
    self:_flush_pending()
end

---@param self NatsClient class instance
---@return void
function M._process_pong(self)
    if #self._pongs > 0 then
        local future = table.remove(self._pongs)
        if type(future) ~= 'string' then
            future:put(true)
        end
        self._pongs_received = self._pongs_received + 1
        self._pings_outstanding = 0
    end
end

---@param self NatsClient class instance
---@param msg Message incoming message
---@return void
function M._process_in_message(self, msg)
    self.stats.in_msgs = self.stats.in_msgs + 1
    self.stats.in_bytes = self.stats.in_bytes + #msg.payload
    ---@type Subscription
    local sub
    if not self._subs[tostring(msg._sid)] then
        return
    end
    self._subs[tostring(msg._sid)]._received = self._subs[tostring(msg._sid)]._received + 1
    if self._subs[tostring(msg._sid)]._max_msgs > 0 and self._subs[tostring(msg._sid)]._received >= self._subs[tostring(msg._sid)]._max_msgs then
        sub = table.deepcopy(self._subs[tostring(msg._sid)])
        self._subs[tostring(msg._sid)] = nil
    else
        sub = self._subs[tostring(msg._sid)]
    end
    sub._pending_size = sub._pending_size + #msg.payload
    if sub._pending_bytes_limit > 0 and sub._pending_size >= sub._pending_bytes_limit then
        self._cb.error_cb(Errors.slow_consumer)
        return
    end
    sub._pending_queue:put(msg)
end

---@param self NatsClient class instance
---@param msg table<string, string|number|table>
---@return void
function M._process_msg(self, msg)
    if msg.type == Protocol.constants.ok then
        return
    elseif msg.type == Protocol.constants.err then
        self:_process_err(self._parser.error_parse(msg.payload))
    elseif msg.type == Protocol.constants.ping then
        self:_process_ping()
    elseif msg.type == Protocol.constants.pong then
        self:_process_pong()
    elseif msg.type == Protocol.constants.info then
        local ok, err = pcall(self._process_info, self, msg.payload)
        if not ok then
            self._cb.error_cb(err)
        end
    elseif msg.type == Protocol.constants.msg or msg.type == Protocol.constants.hmsg then
        local message = Message.new(
                self, msg.sid, msg.subject, msg.reply_subject or nil, msg.payload, msg.headers or nil
        )
        fiber.new(self._process_in_message, self, message)
    end
end

---@param self NatsClient class instance
---@return void
function M._read_loop(self)
    while true do
        fiber.yield()
        if (self:is_closed() or self:is_reconnecting()) or self._transport == nil then
            break
        end
        local read_result = self._transport:read()
        if not read_result.success then
            self._cb.error_cb(read_result.error)
            self:_process_op_err(read_result.error)
            break
        end
        local parse_result = self._parser:parse(read_result.data)
        if parse_result.success then
            self:_process_msg(parse_result.data)
        else
            if parse_result.error == Errors.protocol then
                self:_process_op_err(parse_result.error)
                break
            end
        end
    end
end

-- processes --

-- properties --

---@param self NatsClient class instance
---@return URI|nil connected server uri
function M.connected_url(self)
    if self._current_server ~= nil and self:is_connected() then
        return self._current_server.uri
    end
    return nil
end

---@param self NatsClient class instance
---@return URI[] servers uri list
function M.servers(self)
    local servers = {}
    for _, v in ipairs(self._server_pool) do
        table.insert(servers, v.uri)
    end
    return servers
end

---@param self NatsClient class instance
---@return URI[] servers uri list
function M.discovered_servers(self)
    local servers = {}
    for _, v in ipairs(self._server_pool) do
        if v.discovered then
            table.insert(servers, v.uri)
        end
    end
    return servers
end

---@param self NatsClient class instance
---@return number|nil max payload which we received from the servers INFO
function M.max_payload(self)
    return self._current_server.info.max_payload or nil
end

---@param self NatsClient class instance
---@return number|nil client id which we received from the servers INFO
function M.client_id(self)
    return self._current_server.info.client_id or nil
end

---@param self NatsClient class instance
---@return Error|nil last error which may have occurred
function M.last_error(self)
    return self._error or nil
end

---@param self NatsClient class instance
---@return boolean
function M.is_closed(self)
    return self._status == status.closed
end

---@param self NatsClient class instance
---@return boolean
function M.is_reconnecting(self)
    return self._status == status.reconnecting
end

---@param self NatsClient class instance
---@return boolean
function M.is_connected(self)
    return self._status == status.connected
end

---@param self NatsClient class instance
---@return boolean
function M.is_connecting(self)
    return self._status == status.connecting
end

---@param self NatsClient class instance
---@return boolean
function M.is_draining(self)
    return self._status == status.draining_subs or self._status == status.draining_pubs
end

---@param self NatsClient class instance
---@return boolean
function M.is_draining_pubs(self)
    return self._status == status.draining_pubs
end

---@param self NatsClient class instance
---@return Version|nil the Version of the server to which the client is currently connected.
function M.connected_server_version(self)
    if self._current_server and self._current_server.info then
        return self._current_server.info.version
    end
    return nil
end

-- properties --


return M
