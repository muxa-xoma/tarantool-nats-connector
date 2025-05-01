local NatsProtocolConstants = require('nats.protocol.constants')

---@class NatsClientCommand the class is a constructor of client commands
---@field public new function returns an instance of the class
---@field public connect function returns connection string
---@field public publish function returns publish string
---@field public headers_publish function returns publish string with headers
---@field public subscribe function returns subscribe string
---@field public unsubscribe function returns unsubscribe string
---@field public ping function returns ping string
---@field public pong function returns pong string
local NatsClientCommand = {}
NatsClientCommand.__index = NatsClientCommand

---@return NatsClientCommand class instance
function NatsClientCommand.new()
    return setmetatable({}, NatsClientCommand)
end

---@param conf string configuration string
---@return string command to connect to nats server
function NatsClientCommand.connect(_, conf)
    return table.concat({ NatsProtocolConstants.connect, ' ', conf, NatsProtocolConstants.delimiter })
end

---@param subject string the subject in which the message is published
---@param payload string message payload
---@param reply_subject string|nil the subject in which the response to the message will be expected
---@return string command to publish a message in nats
function NatsClientCommand.publish(_, subject, payload, reply_subject)
    local msg_t = { NatsProtocolConstants.pub, ' ', subject, ' ', #payload, NatsProtocolConstants.delimiter,
                    payload, NatsProtocolConstants.delimiter }
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
function NatsClientCommand.headers_publish(_, subject, payload, headers, reply_subject)
    local headers_t = { NatsProtocolConstants.headers, NatsProtocolConstants.delimiter }
    for k, v in pairs(headers) do
        table.insert(headers_t, tostring(k))
        table.insert(headers_t, ': ')
        table.insert(headers_t, tostring(v))
        table.insert(headers_t, NatsProtocolConstants.delimiter)
    end
    table.insert(headers_t, NatsProtocolConstants.delimiter)
    local headers_s = table.concat(headers_t)
    local msg_t = {
        NatsProtocolConstants.hpub, ' ', subject, ' ', #headers_s, ' ', #headers_s + #payload,
        NatsProtocolConstants.delimiter, headers_s, payload, NatsProtocolConstants.delimiter
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
function NatsClientCommand.subscribe(_, subject, sid, group)
    local msg_t = { NatsProtocolConstants.sub, ' ', subject, ' ', sid, NatsProtocolConstants.delimiter }
    if group ~= nil then
        table.insert(msg_t, 4,  ' ' .. group)
    end
    return table.concat(msg_t)
end

---@param sid string|number unique client identifier
---@param max_msg string|number|nil number of messages to wait for before automatically unsubscribing
---@return string command to subscribe to a subject in nats
function NatsClientCommand.unsubscribe(_, sid, max_msg)
    local msg_t = { NatsProtocolConstants.unsub, ' ', sid, NatsProtocolConstants.delimiter }
    if max_msg ~= nil then
        table.insert(msg_t, 4,  ' ' .. max_msg)
    end
    return table.concat(msg_t)
end

---@return string command to ping in nats
function NatsClientCommand.ping()
    return table.concat({ NatsProtocolConstants.ping, NatsProtocolConstants.delimiter })
end

---@return string command to pong in nats
function NatsClientCommand.pong()
    return table.concat({ NatsProtocolConstants.pong, NatsProtocolConstants.delimiter })
end


return NatsClientCommand
