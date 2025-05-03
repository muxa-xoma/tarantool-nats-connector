local log = require('log')

local Result = require('nats.utils.result')
local NatsErrorEnum = require('nats.utils.errors')


---@class NatsClientOptions @class for NATS client options
---@field private _validate_result Result @Result validation
---@field public error_cb function @Callback to report errors
---@field public disconnected_cb function|nil @Callback to report disconnection from NATS
---@field public closed_cb function|nil @Callback to report when client stops reconnection to NATS
---@field public discovered_server_cb function|nil @Callback to report when a new server joins the cluster
---@field public reconnected_cb function|nil @Callback to report when client reconnected to server
---@field public name string|nil @Label the connection with name (shown in NATS monitoring)
---@field public pedantic boolean @Turns on additional strict format checking, e.g. for properly formed subjects
---@field public verbose boolean @Turns on +OK protocol acknowledgements
---@field public allow_reconnect boolean @Ability to reconnect to servers
---@field public connect_timeout number @Server connection timeout
---@field public reconnect_time_wait number @Wait time between reconnects
---@field public max_reconnect_attempts number @Maximum number of reconnection attempts
---@field public ping_interval number @Interval between sending pings to the server
---@field public max_outstanding_pings number @Maximum number of failed pings
---@field public dont_randomize boolean @Do not mix servers in the pool
---@field public no_echo boolean @Disabling the echo parameter
---@field public user string|nil @User to connect to the server
---@field public password string|nil @Password to connect to the server
---@field public drain_timeout number @Waiting for a graceful disconnect from the server
---@field public inbox_prefix string @Prefix for random topics
---@field public pending_size number @Max size of the pending buffer for publishing commands
---@field public flush_timeout number @Timeout for flushing pending buffer
---@field public flusher_queue_size number @Size of the flusher queue
---@field private _validate fun(self: NatsClientOptions, options: table<string, any>|nil): void @Validate options
---@field private _merge fun(self: NatsClientOptions): void @Merge options and defaults
---@field public new fun(self: NatsClientOptions, options: table<string, any>|nil): Result @Create a new instance of NatsClientOptions
local NatsClientOptions = {
    error_cb = function(err)
        if type(err) == 'table' then
            log.error('%s [%s]: %s', err.type, err.code, err.message)
        else
            log.error(err)
        end
    end,
    allow_reconnect = true,
    verbose = false,
    pedantic = false,
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
NatsClientOptions.__index = NatsClientOptions

---@param options table<string, any>|nil @Options
---@return Result
function NatsClientOptions.new(options)
    local self = setmetatable({}, NatsClientOptions)
    self:_validate(options)
    if not self._validate_result.success then
        return self._validate_result
    end
    self:_merge()
    return Result.new(self)
end

---@param self NatsClientOptions @instance class
---@param options table<string, any> @options
---@return void
function NatsClientOptions._validate(self, options)
    if options == nil then
        self._validate_result = Result.new({})
    elseif options ~= nil and type(options) ~= 'table' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': options must be a table'
        )
    elseif options.error_cb ~= nil and type(options.error_cb) ~= 'function' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': error_cb must be a function'
        )
    elseif options.disconnected_cb ~= nil and type(options.disconnected_cb) ~= 'function' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': disconnected_cb must be a function'
        )
    elseif options.closed_cb ~= nil and type(options.closed_cb) ~= 'function' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': closed_cb must be a function'
        )
    elseif options.discovered_server_cb ~= nil and type(options.discovered_server_cb) ~= 'function' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': discovered_server_cb must be a function'
        )
    elseif options.reconnected_cb ~= nil and type(options.reconnected_cb) ~= 'function' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': reconnected_cb must be a function'
        )
    elseif options.name ~= nil and type(options.name) ~= 'string' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': name must be a string'
        )
    elseif options.user ~= nil and type(options.user) ~= 'string' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': user must be a string'
        )
    elseif options.password ~= nil and type(options.password) ~= 'string' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': password must be a string'
        )
    elseif options.no_echo ~= nil and type(options.no_echo) ~= 'boolean' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': no_echo must be a boolean'
        )
    elseif options.pedantic ~= nil and type(options.pedantic) ~= 'boolean' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': pedantic must be a boolean'
        )
    elseif options.verbose ~= nil and type(options.verbose) ~= 'boolean' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': verbose must be a boolean'
        )
    elseif options.allow_reconnect ~= nil and type(options.allow_reconnect) ~= 'boolean' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': allow_reconnect must be a boolean'
        )
    elseif options.connect_timeout ~= nil and type(options.connect_timeout) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': connect_timeout must be a number'
        )
    elseif options.reconnect_time_wait ~= nil and type(options.reconnect_time_wait) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': reconnect_time_wait must be a number'
        )
    elseif options.max_reconnect_attempts ~= nil and type(options.max_reconnect_attempts) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': max_reconnect_attempts must be a number'
        )
    elseif options.ping_interval ~= nil and type(options.ping_interval) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': ping_interval must be a number'
        )
    elseif options.max_outstanding_pings ~= nil and type(options.max_outstanding_pings) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': max_outstanding_pings must be a number'
        )
    elseif options.drain_timeout ~= nil and type(options.drain_timeout) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': drain_timeout must be a number'
        )
    elseif options.inbox_prefix ~= nil and type(options.inbox_prefix) ~= 'string' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': inbox_prefix must be a string'
        )
    elseif options.pending_size ~= nil and type(options.pending_size) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': pending_size must be a number'
        )
    elseif options.flush_timeout ~= nil and type(options.flush_timeout) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': flush_timeout must be a number'
        )
    elseif options.flusher_queue_size ~= nil and type(options.flusher_queue_size) ~= 'number' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': flusher_queue_size must be a number'
        )
    elseif options.dont_randomize ~= nil and type(options.dont_randomize) ~= 'boolean' then
        self._validate_result = Result.new(
                nil,
                NatsErrorEnum.invalid_connect_params,
                ': dont_randomize must be a boolean'
        )
    else
        self._validate_result = Result.new(options)
    end
end

---@param self NatsClientOptions @instance class
---@return void
function NatsClientOptions._merge(self)
    for key, value in pairs(self._validate_result.data) do
        self[key] = value
    end
end


return NatsClientOptions
