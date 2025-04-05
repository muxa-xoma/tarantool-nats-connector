local nats_protocol_const = require('nats.protocol.constants')

---@class NatsClientCommand the class is a constructor of client commands
local M = {}
M.__index = M

---@return NatsClientCommand class instance
function M.new()
    return setmetatable({}, M)
end

---@param conf string configuration string
---@return string command to connect to nats server
function M.connect(_, conf)
    return table.concat({ nats_protocol_const.connect, ' ', conf, nats_protocol_const.delimiter })
end

---@param subject string the subject in which the message is published
---@param payload string message payload
---@param reply_subject string|nil the subject in which the response to the message will be expected
---@return string command to publish a message in nats
function M.publish(_, subject, payload, reply_subject)
    local msg_t = { nats_protocol_const.pub, ' ', subject, ' ', #payload, nats_protocol_const.delimiter,
                    payload, nats_protocol_const.delimiter }
    if reply_subject ~= nil then
        table.insert(msg_t, 4,  ' ' .. reply_subject)
    end
    return table.concat(msg_t)
end

---@param subject string the subject in which the message is published
---@param payload string message payload
---@param headers table <string, string> message headers
---@param reply_subject string|nil the subject in which the response to the message will be expected
---@return string command to publish a message with headers in nats
function M.headers_publish(_, subject, payload, headers, reply_subject)
    local headers_t = { nats_protocol_const.headers, nats_protocol_const.delimiter }
    for k, v in pairs(headers) do
        table.insert(headers_t, tostring(k))
        table.insert(headers_t, ': ')
        table.insert(headers_t, tostring(v))
        table.insert(headers_t, nats_protocol_const.delimiter)
    end
    table.insert(headers_t,nats_protocol_const.delimiter)
    local headers_s = table.concat(headers_t)
    local msg_t = {
        nats_protocol_const.hpub, ' ', subject, ' ', #headers_s, ' ', #headers_s + #payload,
        nats_protocol_const.delimiter, headers_s, payload, nats_protocol_const.delimiter
    }
    if reply_subject ~= nil then
        table.insert(msg_t, 4,  ' ' .. reply_subject)
    end
    return table.concat(msg_t)
end

---@param subject string subscription subject
---@param sid string|number unique client identifier
---@param group string|nil group for subscription
---@return string command to subscribe to a subject in nats
function M.subscribe(_, subject, sid, group)
    local msg_t = { nats_protocol_const.sub, ' ', subject, ' ', sid, nats_protocol_const.delimiter }
    if group ~= nil then
        table.insert(msg_t, 4,  ' ' .. group)
    end
    return table.concat(msg_t)
end

---@param sid string|number unique client identifier
---@param max_msg string|number|nil number of messages to wait for before automatically unsubscribing
---@return string command to subscribe to a subject in nats
function M.unsubscribe(_, sid, max_msg)
    local msg_t = { nats_protocol_const.unsub, ' ', sid, nats_protocol_const.delimiter }
    if max_msg ~= nil then
        table.insert(msg_t, 4,  ' ' .. max_msg)
    end
    return table.concat(msg_t)
end

---@return string command to ping in nats
function M.ping()
    return table.concat({ nats_protocol_const.ping, nats_protocol_const.delimiter })
end

---@return string command to pong in nats
function M.pong()
    return table.concat({ nats_protocol_const.pong, nats_protocol_const.delimiter })
end


return M
