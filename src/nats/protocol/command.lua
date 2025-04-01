---@class NatsClientCommand the class is a constructor of client commands
---@field private _delimiter string message separator
---@field private _connect string connection command
---@field private _pub string post command
---@field private _hpub string command to publish a message with headers
---@field private _sub string subscribe to subject command
---@field private _unsub string unsubscribe command from subject
---@field private _ping string ping command
---@field private _pong string pong command
local M = {
    _delimiter = '\r\n',
    _headers = 'NATS/1.0',
    _connect = 'CONNECT',
    _pub = 'PUB',
    _hpub = 'HPUB',
    _sub = 'SUB',
    _unsub = 'UNSUB',
    _ping = 'PING',
    _pong = 'PONG'
}
M.__index = M

---@return NatsClientCommand class instance
function M.new()
    return setmetatable({}, M)
end

---@param self NatsClientCommand class instance
---@param conf string configuration string
---@return string command to connect to nats server
function M.connect(self, conf)
    return table.concat({ self._connect, ' ', conf, self._delimiter })
end

---@param self NatsClientCommand class instance
---@param subject string the subject in which the message is published
---@param payload string message payload
---@param reply_subject string|nil the subject in which the response to the message will be expected
---@return string command to publish a message in nats
function M.publish(self, subject, payload, reply_subject)
    local msg_t = { self._pub, ' ', subject, ' ', #payload, self._delimiter, payload, self._delimiter }
    if reply_subject ~= nil then
        table.insert(msg_t, 4,  ' ' .. reply_subject)
    end
    return table.concat(msg_t)
end

---@param self NatsClientCommand class instance
---@param subject string the subject in which the message is published
---@param payload string message payload
---@param headers table <string, string> message headers
---@param reply_subject string|nil the subject in which the response to the message will be expected
---@return string command to publish a message with headers in nats
function M.headers_publish(self, subject, payload, headers, reply_subject)
    local headers_t = { self._headers, self._delimiter }
    for k, v in pairs(headers) do
        table.insert(headers_t, tostring(k))
        table.insert(headers_t, ': ')
        table.insert(headers_t, tostring(v))
        table.insert(headers_t, self._delimiter)
    end
    table.insert(headers_t, self._delimiter)
    local headers_s = table.concat(headers_t)
    local msg_t = {
        self._hpub, ' ', subject, ' ', #headers_s, ' ', #headers_s + #payload,
        self._delimiter, headers_s, payload, self._delimiter
    }
    if reply_subject ~= nil then
        table.insert(msg_t, 4,  ' ' .. reply_subject)
    end
    return table.concat(msg_t)
end

---@param self NatsClientCommand class instance
---@param subject string subscription subject
---@param sid string|number unique client identifier
---@param group string|nil group for subscription
---@return string command to subscribe to a subject in nats
function M.subscribe(self, subject, sid, group)
    local msg_t = { self._sub, ' ', subject, ' ', sid, self._delimiter }
    if group ~= nil then
        table.insert(msg_t, 4,  ' ' .. group)
    end
    return table.concat(msg_t)
end

---@param self NatsClientCommand class instance
---@param sid string|number unique client identifier
---@param max_msg string|number|nil number of messages to wait for before automatically unsubscribing
---@return string command to subscribe to a subject in nats
function M.unsubscribe(self, sid, max_msg)
    local msg_t = { self._unsub, ' ', sid, self._delimiter }
    if max_msg ~= nil then
        table.insert(msg_t, 4,  ' ' .. max_msg)
    end
    return table.concat(msg_t)
end

---@param self NatsClientCommand class instance
---@return string command to ping in nats
function M.ping(self)
    return table.concat({ self._ping, self._delimiter })
end

---@param self NatsClientCommand class instance
---@return string command to pong in nats
function M.pong(self)
    return table.concat({ self._pong, self._delimiter })
end


return M
