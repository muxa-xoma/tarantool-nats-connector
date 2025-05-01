local Result = require('nats.utils.result.init')
local NatsProtocolConstants = require('nats.protocol.constants')
local NatsErrorEnum = require('nats.utils.errors')

---@class NatsParserStatesEnum: table
---@field public awaiting_control_line
---@field public awaiting_msg_headers
---@field public awaiting_msg_payload
---@field public need_return
---@field public error_reading_data
local NatsParserStatesEnum = {
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
local NatsParser = {}
NatsParser.__index = NatsParser


---@return NatsParser class instance
function NatsParser.new()
    local self = setmetatable({}, NatsParser)
    self:_reset()
    return self
end

---@param self NatsParser class instance
---@return void
function NatsParser._reset(self)
    self._buffer = ''
    self._state = NatsParserStatesEnum.awaiting_control_line
    ---@type table < string, string|number >
    self._msg = {}
end

---@param self NatsParser class instance
---@param control_line string command message line
---@return void
function NatsParser._parse_control_msg(self, control_line)
    local slices  = {}
    for slice in control_line:gmatch('[^%s]+') do
        table.insert(slices, slice)
    end
    self._msg.type = slices[1]
    if self._msg.type == NatsProtocolConstants.ping then
        self._state = NatsParserStatesEnum.need_return
    elseif self._msg.type == NatsProtocolConstants.pong then
        self._state = NatsParserStatesEnum.need_return
    elseif self._msg.type == NatsProtocolConstants.ok then
        self._state = NatsParserStatesEnum.need_return
    elseif self._msg.type == NatsProtocolConstants.info then
        table.remove(slices, 1)
        self._msg.payload = table.concat(slices, ' ')
        self._state = NatsParserStatesEnum.need_return
    elseif self._msg.type == NatsProtocolConstants.err then
        table.remove(slices, 1)
        self._msg.payload = table.concat(slices, ' ')
        self._state = NatsParserStatesEnum.need_return
    elseif self._msg.type == NatsProtocolConstants.msg then
        self._msg.subject = slices[2]
        self._msg.sid = tonumber(slices[3])
        if #slices == 4 then
            self._msg.payload_len = tonumber(slices[4])
        else
            self._msg.reply_subject = slices[4]
            self._msg.payload_len = tonumber(slices[5])
        end
        self._state = NatsParserStatesEnum.awaiting_msg_payload
    elseif self._msg.type == NatsProtocolConstants.hmsg then
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
        self._state = NatsParserStatesEnum.awaiting_msg_headers
    else
        self._state = NatsParserStatesEnum.error_reading_data
    end
end

---@param self NatsParser class instance
---@param headers_s string headers in string format
---@return void
function NatsParser._parse_msg_headers(self, headers_s)
    local slices = {}
    for slice in headers_s:gmatch(string.format('[^%s]+', NatsProtocolConstants.delimiter)) do
        table.insert(slices, slice)
    end
    if table.remove(slices, 1) ~= NatsProtocolConstants.headers then
        self._state = NatsParserStatesEnum.error_reading_data
    else
        self._msg.headers = {}
        for _, v in ipairs(slices) do
            local header = v:split(': ')
            self._msg.headers[header[1]] = header[2]
        end
        self._state = NatsParserStatesEnum.awaiting_msg_payload
    end
end

---@param self NatsParser class instance
---@param data string subtracted data
---@return Result
function NatsParser.parse(self, data)
    self._buffer = self._buffer .. data
    while  self._buffer:find(NatsProtocolConstants.delimiter) ~= nil and self._state ~= NatsParserStatesEnum.need_return do
        if self._state == NatsParserStatesEnum.awaiting_control_line then
            self._msg = {}
            local control_line = self._buffer:match(string.format('[^%s]+', NatsProtocolConstants.delimiter))
            self:_parse_control_msg(control_line)
            self._buffer = self._buffer:sub(1 + #control_line + #NatsProtocolConstants.delimiter)
        elseif self._state == NatsParserStatesEnum.awaiting_msg_payload then
            self._msg.payload = self._buffer:sub(1, self._msg.payload_len)
            self._buffer = self._buffer:sub(1 + self._msg.payload_len + #NatsProtocolConstants.delimiter)
            self._state = NatsParserStatesEnum.need_return
        elseif self._state == NatsParserStatesEnum.awaiting_msg_headers and #self._buffer >= self._msg.headers_len then
            local headers_s = self._buffer:sub(1, self._msg.headers_len)
            self:_parse_msg_headers(headers_s)
            self._buffer = self._buffer:sub(1 + self._msg.headers_len)
        elseif self._state == NatsParserStatesEnum.error_reading_data then
            self:_reset()
            return Result.new(nil, NatsErrorEnum.protocol)
        else
            break
        end
    end
    if self._state == NatsParserStatesEnum.need_return then
        self._state = NatsParserStatesEnum.awaiting_control_line
        return Result.new(table.deepcopy(self._msg))
    else
        return Result.new(nil, NatsErrorEnum.unexpected_eof)
    end
end

---@param err_string string the error text that the server returned
---@return Error recognized error
function NatsParser.error_parse(err_string)
    local err
    if err_string == 'Unknown Protocol Operation' then
        err = NatsErrorEnum.unk_protocol_err
    elseif err_string == 'Attempted To Connect To Route Port' then
        err = NatsErrorEnum.con_route_port
    elseif err_string == 'Authorization Violation' then
        err = NatsErrorEnum.authorization_violation
    elseif err_string == 'Authorization Timeout' then
        err = NatsErrorEnum.authorization_timeout
    elseif err_string == 'Invalid Client Protocol' then
        err = NatsErrorEnum.invalid_client_protocol
    elseif err_string == 'Maximum Control Line Exceeded' then
        err = NatsErrorEnum.max_control_line
    elseif err_string == 'Parser Error' then
        err = NatsErrorEnum.parser_err
    elseif err_string == 'Secure Connection - TLS Required' then
        err = NatsErrorEnum.tls_required
    elseif err_string == 'Stale Connection' then
        err = NatsErrorEnum.stale_connection_serv
    elseif err_string == 'Maximum Connections Exceeded' then
        err = NatsErrorEnum.max_connections
    elseif err_string == 'Slow Consumer' then
        err = NatsErrorEnum.slow_consumer_serv
    elseif err_string == 'Maximum Payload Violation' then
        err = NatsErrorEnum.max_payload_serv
    elseif err_string == 'Invalid Subject' then
        err = NatsErrorEnum.invalid_subject
    elseif string.startswith(err_string, 'Permissions Violation for Subscription to') then
        err = NatsErrorEnum.permission_read_subject
    elseif string.startswith(err_string, 'Permissions Violation for Publish to') then
        err = NatsErrorEnum.permission_write_subject
    else
        err = NatsErrorEnum.unexpected_serv
    end
    return err
end


return NatsParser
