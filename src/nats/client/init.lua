local math = require('math')
local fiber = require('fiber')

local NatsErrorEnum = require('nats.utils.errors')
local Nuid = require('nats.utils.nuid')
local NatsServer = require('nats.client.server')
local Subscription = require('nats.client.subscription')
local Message = require('nats.client.message')
local NatsClientOptions = require('nats.client.options')
local protocol = require('nats.protocol')
local transport = require('nats.transport')


math.randomseed(os.time())

---@class NatsClientStatus enum
---@field disconnected number 0
---@field connected number 1
---@field closed number 2
---@field reconnecting number 3
---@field connecting number 4
---@field draining_subs number 5
---@field draining_pubs number 6
local NatsClientStatus = {
    disconnected = 0,
    connected = 1,
    closed = 2,
    reconnecting = 3,
    connecting = 4,
    draining_subs = 5,
    draining_pubs = 6
}

---@class NatsClient class representing a connection to NATS
---@field private _server_pool NatsServer[] server pool
---@field private _cb table<string, function> callbacks
---@field private _connection_params NatsConnectionParameters connection parameters
---@field private _params table<string, any> client parameters
---@field private _status NatsClientStatus client status
---@field private _nuid Nuid random string generator to generate unique subjects
---@field private _command NatsClientCommand NATS command builder
---@field private _parser NatsParser NATS protocol parser
---@field private _flush_queue userdata fiber channel, used to wait for flushing messages
---@field private _pending string pending data
---@field private _sid number current subscription id
---@field private _subs table<string, Subscription> subscriptions
---@field private _resp_map table<string, function> map of pending responses
---@field private _pongs string[]|userdata[] list of pending pongs
---@field private _pings_outstanding number count of pending pings
---@field private _pongs_received number count of received pongs
---@field private _pending_data_size number count of pending data
---@field public stats {in_msgs:number,out_msgs:number,in_bytes:number,out_bytes:number,reconnects:number,errors_received:number} statistics
---@field private _transport Transport|nil transport
---@field private _error Error|nil last error
---@field private _current_server NatsServer|nil current server
---
---@field private _setup_server_pool fun(servers:string|table):void setup server pool
---@field private _setup_client_options fun(options:NatsConnectionParameters|nil):void setup client options
---@field private _select_next_server fun():void select next server in pool
local NatsClient = {}
NatsClient.__index = NatsClient

-- setup --

---@param servers string|string[] connection string or connection strings list
---@param options table<string, any>|nil connection parameters
---@return NatsClient
function NatsClient.new(servers, options)
    ---@type NatsClient
    local self = setmetatable({}, NatsClient)
    self:_setup_server_pool(servers)
    self:_setup_client_options(options)
    self._status = NatsClientStatus.disconnected
    self._nuid = Nuid.new()
    self._command = protocol.NatsClientCommand.new()
    self._parser = protocol.NatsParser.new()
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
            self:_close(NatsClientStatus.disconnected, false)
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
function NatsClient._setup_server_pool(self, servers)
    if type(servers) ~= 'string' and type(servers) ~= 'table' then
        error(NatsErrorEnum.invalid_connect_params)
    end
    self._server_pool = {}
    -- TODO: schema validation
    if type(servers) == 'string' then
        table.insert(self._server_pool, NatsServer.new(servers))
    else
        for _, v in ipairs(servers) do
            if type(v) ~= 'string' then
                error(NatsErrorEnum.invalid_connect_params)
            end
            table.insert(self._server_pool, NatsServer.new(v))
        end
    end
end

---@param self NatsClient class instance
---@param options table<string, any>|nil connection parameters
---@return void
function NatsClient._setup_client_options(self, options)
    local client_options = NatsClientOptions.new(options)
    if client_options.success then
        options = client_options.data
    else
        error(client_options.error)
    end
    self._cb = {
        error_cb = options.error_cb,
        disconnected_cb = options.disconnected_cb,
        closed_cb = options.closed_cb,
        discovered_server_cb = options.discovered_server_cb,
        reconnected_cb = options.reconnected_cb
    }
    self._connection_params = protocol.NatsConnectionParameters.new(
            options.name,
            options.user,
            options.password,
            nil,
            nil,
            nil,
            not options.no_echo,
            true,
            options.verbose,
            options.pedantic,
            nil
    )
    self._params = {
        allow_reconnect = options.allow_reconnect,
        connect_timeout = options.connect_timeout,
        reconnect_time_wait = options.reconnect_time_wait,
        max_reconnect_attempts = options.max_reconnect_attempts,
        ping_interval = options.ping_interval,
        max_outstanding_pings = options.max_outstanding_pings,
        drain_timeout = options.drain_timeout,
        inbox_prefix = options.inbox_prefix,
        pending_size = options.pending_size,
        flush_timeout = options.flush_timeout,
        flusher_queue_size = options.flusher_queue_size,
        dont_randomize = options.dont_randomize
    }
    if #self._server_pool > 1 and not self._params.dont_randomize then
        table.sort(self._server_pool, function (_, _) return math.random(1, 2) == 1 end)
    end
end

---@param self NatsClient class instance
---@return void
function NatsClient._select_next_server(self)
    while true do
        if #self._server_pool == 0 then
            self._current_server = nil
            error(NatsErrorEnum.no_servers)
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
            self._transport = transport.TCPTransport.new(serv.uri.host, serv.uri.service, self._params.connect_timeout)
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

-- setup --

-- closed --

---@param self NatsClient class instance
---@return void
function NatsClient.close(self)
    self:_close(NatsClientStatus.closed)
end

---@param self NatsClient class instance
---@param status NatsClientStatus the status with which the connection will be closed
---@param do_cbs boolean the need to call callback functions
---@return void
function NatsClient._close(self, status, do_cbs)
    if self:is_closed() then
        self._status = status
        return
    end
    self._status = NatsClientStatus.closed
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
function NatsClient.drain(self)
    if self:is_draining() then
        return
    end
    if self:is_closed() then
        error(NatsErrorEnum.connection_closed)
    end
    if self:is_connecting() or self:is_reconnecting() then
        error(NatsErrorEnum.connection_reconnecting)
    end
    local drain_tasks = {}
    for _, v in pairs(self._subs) do
        local task = fiber.new(v._drain, v)
        table.insert(drain_tasks, task)
    end
    fiber.yield()
    self._status = NatsClientStatus.draining_subs
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
        self._cb.error_cb(NatsErrorEnum.drain_timeout)
    end
    self._status = NatsClientStatus.draining_pubs
    self:flush()
    self._close(NatsClientStatus.closed)
end

-- closed --

-- flusher --

---@param self NatsClient class instance
---@param force_flush boolean wait for an answer
---@return void
function NatsClient._flush_pending(self, force_flush)
    assert(self._flush_queue, 'must be called only from Client.new')
    if not self:is_connected() then
        return
    end
    local future
    if force_flush then
        future = fiber.channel(1)
    else
        future = 'future'
    end
    self._flush_queue:put(future)
    if force_flush then
        local result = future:get(self._params.flush_timeout)
        future:close()
        if result == nil then
            error(NatsErrorEnum.flush_timeout)
        end
    end
end

---@param self NatsClient class instance
---@return void
function NatsClient._flusher(self)
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
function NatsClient._send_ping(self, future)
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
function NatsClient.flush(self, timeout)
    timeout = timeout or self._params.flush_timeout
    if timeout <= 0 then
        error(NatsErrorEnum.bad_timeout)
    end
    if self:is_closed() then
        error(NatsErrorEnum.connection_closed)
    end
    local future = fiber.channel(1)
    fiber.new(self._send_ping, self, future)
    local result = future:get(timeout)
    future:close()
    if result == nil then
        error(NatsErrorEnum.flush_timeout)
    end
end

-- flusher --

-- commands --

---@param self NatsClient class instance
---@param cmd string command
---@param priority boolean whether to send the command first
---@return void
function NatsClient._send_command(self, cmd, priority)
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
function NatsClient._send_publish(self, subject, reply, payload, payload_size, headers)
    if subject == '' then
        error(NatsErrorEnum.bad_subject)
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
function NatsClient.publish(self, subject, payload, reply, headers)
    if self:is_closed() then
        error(NatsErrorEnum.connection_closed)
    end
    if self:is_draining_pubs() then
        error(NatsErrorEnum.connection_draining)
    end
    local payload_size = #payload
    if not self:is_connected() then
        if self._params.pending_size <= 0 or (payload_size + self._pending_data_size > self._params.pending_size) then
            error(NatsErrorEnum.outbound_buffer_limit)
        end
    end
    if payload_size > self._current_server.info.max_payload then
        error(NatsErrorEnum.max_payload)
    end
    self:_send_publish(subject, reply, payload, payload_size, headers)
end

---@param self NatsClient class instance
---@param sid number subscription id
---@return void
function NatsClient._remove_sub(self, sid)
    self._subs[tostring(sid)] = nil
end

---@param self NatsClient class instance
---@param subscription Subscription class instance
---@return void
function NatsClient._send_subscribe(self, subscription)
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
function NatsClient.subscribe(self, subject, queue, cb, max_msgs, pending_msgs_limit, pending_bytes_limit)
    if subject == nil or string.find(subject, ' ') ~= nil then
        error(NatsErrorEnum.bad_subject)
    end
    if queue ~= nil and string.find(queue, ' ') ~= nil then
        error(NatsErrorEnum.bad_subject)
    end
    if self:is_closed() then
        error(NatsErrorEnum.connection_closed)
    end
    if self:is_draining() then
        error(NatsErrorEnum.connection_draining)
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
function NatsClient._send_unsubscribe(self, sid, limit)
    self:_send_command(self._command:unsubscribe(sid, limit))
    self:_flush_pending()
end

---@param self NatsClient class instance
---@return string
function NatsClient.new_inbox(self)
    return table.concat({ self._params.inbox_prefix, self._nuid:next() }, '.')
end

---@param msg Message returned message
---@return void
function NatsClient._request_sub_callback(msg)
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
function NatsClient._request(self, subject, payload, headers, timeout)
    if self:is_draining_pubs() then
        error(NatsErrorEnum.connection_draining)
    end
    local future = fiber.channel(1)
    local resp_subject = self:new_inbox()
    self._resp_map[resp_subject] = future
    self:subscribe(resp_subject, nil, self._request_sub_callback)
    self:publish(subject, payload, resp_subject, headers)
    local result = future:get(timeout)
    future:close()
    if result == nil then
        error(NatsErrorEnum.timeout)
    end
    return result
end

---@param self NatsClient class instance
---@param subject string subject from which the message came
---@param payload string message payload
---@param headers table<string, string>|nil message headers
---@param timeout number|nil response timeout
---@return Message
function NatsClient.request(self, subject, payload, headers, timeout)
    timeout = timeout or 0.5
    return self:_request(subject, payload, headers, timeout)
end

-- commands --

-- processes --

---@param self NatsClient class instance
---@param info_string string json string with server information
---@param initial_connection boolean is this the first attempt to connect
---@return void
function NatsClient._process_info(self, info_string, initial_connection)
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
            local serv = NatsServer.new(v)
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
function NatsClient._attempt_reconnect(self)
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
                        self._status = NatsClientStatus.reconnecting
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
                        self._status = NatsClientStatus.connected
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
function NatsClient._process_disconnect(self)
    self._status = NatsClientStatus.disconnected
end

---@param self NatsClient class instance
---@param err Error error message
---@return void
function NatsClient._process_op_err(self, err)
    if self:is_connecting() or self:is_closed() or self:is_reconnecting() then
        return
    end
    if self._params.allow_reconnect and self:is_connected() then
        self._status = NatsClientStatus.reconnecting
        self._parser:_reset()
        if self._reconnection_task ~= nil and self._reconnection_task:status() ~= 'dead' then
            self._reconnection_task:cancel()
        end
        self._reconnection_task = fiber.new(self._attempt_reconnect, self)
    else
        self:_process_disconnect()
        self._error = err
        self:_close(NatsClientStatus.closed, true)
    end
end

---@param self NatsClient class instance
---@return void
function NatsClient._process_connect_init(self)
    assert(self._transport, 'must be called only from Client.new')
    assert(self._current_server, 'must be called only from Client.new')
    self._status = NatsClientStatus.connecting
    local read_result = self._transport:read()
    if not read_result.success then
        error(read_result.error)
    end
    local read_data = self._parser:parse(read_result.data)
    if not read_data.success then
        error(read_data.error)
    end
    if read_data.data.type == protocol.NatsProtocolConstants.ping then
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
    if read_data.data.type ~= protocol.NatsProtocolConstants.info then
        error(NatsErrorEnum.connection_not_info_msg)
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
        if read_data.data.type == protocol.NatsProtocolConstants.err then
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
    if read_data.data.type == protocol.NatsProtocolConstants.pong then
        self._status = NatsClientStatus.connected
    elseif read_data.data.type == protocol.NatsProtocolConstants.err then
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
function NatsClient._ping_interval(self)
    while true do
        fiber.sleep(self._params.ping_interval)
        if self:is_connected() then
            self._pings_outstanding = self._pings_outstanding + 1
            if self._pings_outstanding > self._params.max_outstanding_pings then
                self:_process_op_err(NatsErrorEnum.stale_connection)
                return
            end
            self:_send_ping()
        end
    end
end

---@param self NatsClient class instance
---@param err Error error
---@return void
function NatsClient._process_err(self, err)
    self._error = err
    if err.code == NatsErrorEnum.stale_connection_serv.code then
        self:_process_op_err(NatsErrorEnum.stale_connection_serv)
        return
    end
    if (err.code > NatsErrorEnum.unk_protocol_err.code and err.code <= NatsErrorEnum.max_payload_serv.code) or err.code == NatsErrorEnum.unexpected_serv.code then
        local do_cbs = false
        if not self:is_connecting() then
            do_cbs = true
        end
        fiber.new(self._close, self, NatsClientStatus.closed, do_cbs)
    end
end

---@param self NatsClient class instance
---@return void
function NatsClient._process_ping(self)
    self:_send_command(self._command:pong())
    self:_flush_pending()
end

---@param self NatsClient class instance
---@return void
function NatsClient._process_pong(self)
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
function NatsClient._process_in_message(self, msg)
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
        self._cb.error_cb(NatsErrorEnum.slow_consumer)
        return
    end
    sub._pending_queue:put(msg)
end

---@param self NatsClient class instance
---@param msg table<string, string|number|table>
---@return void
function NatsClient._process_msg(self, msg)
    if msg.type == protocol.NatsProtocolConstants.ok then
        return
    elseif msg.type == protocol.NatsProtocolConstants.err then
        self.stats.errors_received = self.stats.errors_received + 1
        self:_process_err(self._parser.error_parse(msg.payload))
    elseif msg.type == protocol.NatsProtocolConstants.ping then
        self:_process_ping()
    elseif msg.type == protocol.NatsProtocolConstants.pong then
        self:_process_pong()
    elseif msg.type == protocol.NatsProtocolConstants.info then
        local ok, err = pcall(self._process_info, self, msg.payload)
        if not ok then
            self._cb.error_cb(err)
        end
    elseif msg.type == protocol.NatsProtocolConstants.msg or msg.type == protocol.NatsProtocolConstants.hmsg then
        local message = Message.new(
                self, msg.sid, msg.subject, msg.reply_subject or nil, msg.payload, msg.headers or nil
        )
        fiber.new(self._process_in_message, self, message)
    end
end

---@param self NatsClient class instance
---@return void
function NatsClient._read_loop(self)
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
            if parse_result.error == NatsErrorEnum.protocol then
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
function NatsClient.connected_url(self)
    if self._current_server ~= nil and self:is_connected() then
        return self._current_server.uri
    end
    return nil
end

---@param self NatsClient class instance
---@return URI[] servers uri list
function NatsClient.servers(self)
    local servers = {}
    for _, v in ipairs(self._server_pool) do
        table.insert(servers, v.uri)
    end
    return servers
end

---@param self NatsClient class instance
---@return URI[] servers uri list
function NatsClient.discovered_servers(self)
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
function NatsClient.max_payload(self)
    return self._current_server.info.max_payload or nil
end

---@param self NatsClient class instance
---@return number|nil client id which we received from the servers INFO
function NatsClient.client_id(self)
    return self._current_server.info.client_id or nil
end

---@param self NatsClient class instance
---@return Error|nil last error which may have occurred
function NatsClient.last_error(self)
    return self._error or nil
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_closed(self)
    return self._status == NatsClientStatus.closed
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_reconnecting(self)
    return self._status == NatsClientStatus.reconnecting
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_connected(self)
    return self._status == NatsClientStatus.connected
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_connecting(self)
    return self._status == NatsClientStatus.connecting
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_draining(self)
    return self._status == NatsClientStatus.draining_subs or self._status == NatsClientStatus.draining_pubs
end

---@param self NatsClient class instance
---@return boolean
function NatsClient.is_draining_pubs(self)
    return self._status == NatsClientStatus.draining_pubs
end

---@param self NatsClient class instance
---@return Version|nil the Version of the server to which the client is currently connected.
function NatsClient.connected_server_version(self)
    if self._current_server and self._current_server.info then
        return self._current_server.info.version
    end
    return nil
end

-- properties --


return NatsClient
