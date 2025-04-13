local result = require('nats.utils.result.init')
local const = require('nats.protocol.constants')
local errors = require('nats.utils.errors')

---@class NatsParserStatesEnum: table
---@field public awaiting_control_line
---@field public awaiting_msg_headers
---@field public awaiting_msg_payload
---@field public need_return
---@field public error_reading_data
local states = {
    awaiting_control_line = 1,
    awaiting_msg_headers = 2,
    awaiting_msg_payload = 3,
    need_return = 4,
    error_reading_data = 5
}

---@class NatsParser class that represents a parser of messages from the nats server
---@field private _buffer string message buffer being processed
---@field private _state NatsParserStatesEnum
---@field private _msg table < string, string|number >
---@field private _reset function resets class
---@field private _parse_control_msg function recognizes the control line of the message
---@field private _parse_msg_headers function recognizes message headers
---@field public new function returns an instance of the class
---@field public parse function returns the recognized message
---@field public error_parse function return recognized error
local M = {}
M.__index = M


---@return NatsParser class instance
function M.new()
    local self = setmetatable({}, M)
    self:_reset()
    return self
end

---@param self NatsParser class instance
---@return void
function M._reset(self)
    self._buffer = ''
    self._state = states.awaiting_control_line
    ---@type table < string, string|number >
    self._msg = {}
end

---@param self NatsParser class instance
---@param control_line string command message line
---@return void
function M._parse_control_msg(self, control_line)
    local slices  = {}
    for slice in control_line:gmatch('[^%s]+') do
        table.insert(slices, slice)
    end
    if slices[1] == const.ping then
        self._msg.type =  const.ping
        self._state = states.need_return
    elseif slices[1] == const.pong then
        self._msg.type =  const.pong
        self._state = states.need_return
    elseif slices[1] == const.ok then
        self._msg.type =  const.ok
        self._state = states.need_return
    elseif slices[1] == const.info then
        self._msg.type =  const.info
        self._msg.payload = slices[2]
        self._state = states.need_return
    elseif slices[1] == const.err then
        self._msg.type =  const.err
        table.remove(slices, 1)
        self._msg.payload = table.concat(slices, ' ')
        self._state = states.need_return
    elseif slices[1] == const.msg then
        self._msg.type =  const.msg
        self._msg.subject = slices[2]
        self._msg.sid = tonumber(slices[3])
        if #slices == 4 then
            self._msg.payload_len = tonumber(slices[4])
        else
            self._msg.reply_subject = slices[4]
            self._msg.payload_len = tonumber(slices[5])
        end
        self._state = states.awaiting_msg_payload
    elseif slices[1] == const.hmsg then
        self._msg.type =  const.hmsg
        self._msg.subject = slices[2]
        self._msg.sid = tonumber(slices[3])
        if #slices == 5 then
            self._msg.headers_len = tonumber(slices[4])
            self._msg.payload_len = tonumber(slices[5]) - tonumber(slices[4])
        else
            self._msg.reply_subject = slices[4]
            self._msg.headers_len = tonumber(slices[5])
            self._msg.payload_len = tonumber(slices[6]) - tonumber(slices[5])
        end
        self._state = states.awaiting_msg_headers
    else
        self._state = states.error_reading_data
    end
end

---@param self NatsParser class instance
---@param headers_s string headers in string format
---@return void
function M._parse_msg_headers(self, headers_s)
    local slices = {}
    for slice in headers_s:gmatch(string.format('[^%s]+', const.delimiter)) do
        table.insert(slices, slice)
    end
    if table.remove(slices, 1) ~= const.headers then
        self._state = states.error_reading_data
    else
        self._msg.headers = {}
        for _, v in ipairs(slices) do
            local header = v:split(': ')
            self._msg.headers[header[1]] = header[2]
        end
        self._state = states.awaiting_msg_payload
    end
end

---@param self NatsParser class instance
---@param data string subtracted data
---@return Result
function M.parse(self, data)
    self._buffer = self._buffer .. data
    while  self._buffer:find(const.delimiter) ~= nil and self._state ~= states.need_return do
        if self._state == states.awaiting_control_line then
            self._msg = {}
            local control_line = self._buffer:match(string.format('[^%s]+', const.delimiter))
            self:_parse_control_msg(control_line)
            self._buffer = self._buffer:sub(1 + #control_line + #const.delimiter)
        elseif self._state == states.awaiting_msg_payload then
            self._msg.payload = self._buffer:sub(1, self._msg.payload_len)
            self._buffer = self._buffer:sub(1 + self._msg.payload_len + #const.delimiter)
            self._state = states.need_return
        elseif self._state == states.awaiting_msg_headers and #self._buffer >= self._msg.headers_len then
            local headers_s = self._buffer:sub(1, self._msg.headers_len)
            self:_parse_msg_headers(headers_s)
            self._buffer = self._buffer:sub(1 + self._msg.headers_len)
        elseif self._state == states.error_reading_data then
            self:_reset()
            return result.new(nil, errors.protocol)
        else
            break
        end
    end
    if self._state == states.need_return then
        self._state = states.awaiting_control_line
        return result.new(table.deepcopy(self._msg))
    else
        return result.new(nil, errors.unexpected_eof)
    end
end

---@param err_string string the error text that the server returned
---@return Error recognized error
function M.error_parse(err_string)
    local err
    if err_string == 'Unknown Protocol Operation' then
        err = errors.unk_protocol_err
    elseif err_string == 'Attempted To Connect To Route Port' then
        err = errors.con_route_port
    elseif err_string == 'Authorization Violation' then
        err = errors.authorization_violation
    elseif err_string == 'Authorization Timeout' then
        err = errors.authorization_timeout
    elseif err_string == 'Invalid Client Protocol' then
        err = errors.invalid_client_protocol
    elseif err_string == 'Maximum Control Line Exceeded' then
        err = errors.max_control_line
    elseif err_string == 'Parser Error' then
        err = errors.parser_err
    elseif err_string == 'Secure Connection - TLS Required' then
        err = errors.tls_required
    elseif err_string == 'Stale Connection' then
        err = errors.stale_connection_serv
    elseif err_string == 'Maximum Connections Exceeded' then
        err = errors.max_connections
    elseif err_string == 'Slow Consumer' then
        err = errors.slow_consumer_serv
    elseif err_string == 'Maximum Payload Violation' then
        err = errors.max_payload_serv
    elseif err_string == 'Invalid Subject' then
        err = errors.invalid_subject
    elseif string.startswith(err_string, 'Permissions Violation for Subscription to') then
        err = errors.permission_read_subject
    elseif string.startswith(err_string, 'Permissions Violation for Publish to') then
        err = errors.permission_write_subject
    else
        err = errors.unexpected_serv
    end
    return err
end


return M
