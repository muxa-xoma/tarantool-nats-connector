---@class Message class representing an abstraction of a message received from a NATS server
---@field private _client NatsClient client connected to NATS server
---@field _sid number subscription ID from a message
---@field public subject string subject from which the message came
---@field public reply string subject to which the answer should be sent
---@field public payload string message payload
---@field public headers table <string, string> message headers
---@field public new fun(client: NatsClient, sid: number, subject: string, reply: string, payload: string, headers: table<string, string>):Message returns class instance
---@field public header fun():table<string, string> returns headers table
---@field public sid fun():number returns subscription ID from a message
---@field public respond fun(payload: string):void posts a reply to a message
local Message = {}
Message.__index = Message


---@param client NatsClient client connected to NATS server
---@param sid number subscription ID from a message
---@param subject string subject from which the message came
---@param reply string subject to which the answer should be sent
---@param payload string message payload
---@param headers table <string, string> message headers
function Message.new(client, sid, subject, reply, payload, headers)
    ---@type Message
    local self = setmetatable({}, Message)
    self._client = client
    self._sid = sid or nil
    self.subject = subject or ''
    self.reply = reply or ''
    self.payload = payload or ''
    self.headers = headers or nil
    return self
end

---@param self Message instance class
---@return table<string, string> message headers
function Message.header(self)
    return self.headers
end

---@param self Message instance class
---@return number subscription ID from a message
function Message.sid(self)
    if self._sid == nil then
        error('sid not set')
    end
    return self._sid
end

---@param self Message instance class
---@param payload string return message payload
---@return void
function Message.respond(self, payload)
    if self.reply == nil then
        error('no reply subject available')
    end
    if self._client == nil  then
        error('client not set')
    end
    self._client:publish(self.reply, payload, nil,  self.headers)
end


return Message
