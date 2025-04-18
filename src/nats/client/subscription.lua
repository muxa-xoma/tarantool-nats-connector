local fiber = require('fiber')

local errors = require('nats.utils.errors')


---@class Subscription class representing an abstraction of a subscription to a subject in NATS
---@field private _client NatsClient client connected to NATS server
---@field private _id number subscription ID
---@field private _subject string subscription subject
---@field private _queue string subscription queue
---@field private _max_msgs number maximum number of messages expected from a subscription
---@field private _received number number of messages received
---@field private _cb function function for automatic message processing
---@field private _closed boolean is the subscription inactive
---@field private _pending_msgs_limit number maximum number of messages in the handler queue
---@field private _pending_bytes_limit number maximum number of bytes in the handler queue
---@field private _pending_queue Message[] message queue for processing
---@field private _pending_size number queue size in bytes
---@field public new function returns class instance
---@field public subject function returns subject
---@field public queue function returns queue
---@field public messages function returns an iterator function over the received messages
---@field public pending_msgs function returns the number of messages in the queue for processing
---@field public pending_bytes function returns the number of bytes in the queue for processing
---@field public delivered function returns the number of messages received
---@field public next_msg function returns the next message from the queue
---@field private _start function starts the message handler
---@field public drain function clears the message queue and stops the subscription
---@field private _drain function clears the message queue and stops the subscription
---@field public unsubscribe function unsubscribes from subscription
---@field private _stop_processing function ends subscription
---@field private _wait_for_msgs function automatic message processing function
local M = {}
M.__index = M

---@param client NatsClient client connected to NATS server
---@param id number subscription ID
---@param subject string subscription subject
---@param queue string subscription queue
---@param cb function|nil callback function
---@param max_msgs number maximum number of messages expected from a subscription
---@param pending_msgs_limit number maximum number of messages in the handler queue
---@param pending_bytes_limit number maximum number of bytes in the handler queue
function M.new(client, id, subject, queue, cb, max_msgs, pending_msgs_limit, pending_bytes_limit)
    ---@type Subscription
    local self = setmetatable({}, M)
    self._client = client
    self._id = id or 0
    self._subject = subject or ''
    self._queue = queue or ''
    self._max_msgs = max_msgs or 0
    self._received = 0
    self._cb = cb or nil
    self._closed = false
    self._pending_msgs_limit = pending_msgs_limit or 512 * 1024
    self._pending_bytes_limit = pending_bytes_limit or 128 * 1024 * 1024
    self._pending_queue = fiber.channel(self._pending_msgs_limit)
    self._pending_size = 0
    return self
end

---@param self Subscription instance class
---@return string subscription subject
function M.subject(self)
    return self._subject
end

---@param self Subscription instance class
---@return string subscription queue
function M.queue(self)
    return self._queue
end

---@param self Subscription instance class
---@return function
function M.messages(self)
    if self._message_iterator == nil then
        error('cannot iterate over messages with a non iteration subscription type')
    end
    return self._message_iterator
end

---@param self Subscription instance class
---@return number number of messages awaiting processing
function M.pending_msgs(self)
    return self._pending_queue:count()
end

---@param self Subscription instance class
---@return number number of bytes awaiting processing
function M.pending_bytes(self)
    return self._pending_size
end

---@param self Subscription instance class
---@return number number of delivered messages to this subscription so far
function M.delivered(self)
    return self._received
end

---@param self Subscription instance class
---@param timeout number|nil time in seconds to wait for next message before timing out
---@return Message first message in queue
function M.next_msg(self, timeout)
    if self._client:is_closed() then
        error(errors.connection_closed)
    end
    if self._cb ~= nil then
        error('nats: next_msg cannot be used in async subscriptions')
    end
    timeout = timeout or 1
    local msg = self._pending_queue:get(timeout)
    if msg == nil then
        local err = errors.timeout
        if self._client:is_closed() then
            err = errors.connection_closed
        end
        error(err)
    else
        self._pending_size = self._pending_size - #msg.payload
        return msg
    end
end

---@param self Subscription instance class
---@return void
function M._start(self)
    if self._cb ~= nil then
        if type(self._cb) ~= 'function' then
            error('nats: must use function for subscriptions')
        end
        self._wait_for_msgs_task = fiber.create(self._wait_for_msgs, self)
    else
        self._message_iterator = function()
            local msg = self._pending_queue:get()
            self._pending_size = self._pending_size - #msg.payload
            if self._max_msgs > 0 and self._received >= self._max_msgs then
                self._cancel()
            end
            return msg
        end
    end
end

---@param self Subscription instance class
---@return void
function M.drain(self)
    if self._client:is_closed() then
        error(errors.connection_closed)
    end
    if self._client:is_draining() then
        error(errors.connection_draining)
    end
    if self._closed then
        error(errors.bad_subscription)
    end
    self:_drain()
end

---@param self Subscription instance class
---@return void
function M._drain(self)
    self._client:_send_unsubscribe(self._id)
    self._client:flush()
    if self._cb ~= nil then
        while self:pending_msgs() > 0 do
            fiber.yield()
        end
    else
        if self:pending_msgs() > 0 then
            self._client._cb.error_cb(errors.unsubscribe_queue_not_empty)
        end
    end
    self:_stop_processing()
    self._client:_remove_sub(self._id)
    self._closed = true
end

---@param self Subscription instance class
---@param limit number number of messages expected from subscription
---@return void
function M.unsubscribe(self, limit)
    limit = limit or 0
    if self._client:is_closed() then
        error(errors.connection_closed)
    end
    if self._client:is_draining() then
        error(errors.connection_draining)
    end
    if self._closed then
        error(errors.bad_subscription)
    end
    self._max_msgs = limit
    if limit == 0 or (self._received >= limit and self._pending_queue:is_empty()) then
        self._closed = true
        self:_stop_processing()
        self._client:_remove_sub(self._id)
    end
    if not self._client:is_reconnecting() then
        self._client:_send_unsubscribe(self._id, limit)
    end
end

---@param self Subscription instance class
---@return void
function M._stop_processing(self)
    if self._wait_for_msgs_task and self._wait_for_msgs_task:status() ~= 'dead' then
        self._wait_for_msgs_task:cancel()
    end
    if self._pending_queue ~= nil then
        self._pending_queue:close()
    end
    if self._message_iterator ~= nil then
        self._message_iterator = nil
    end
end

---@param self Subscription instance class
---@return void
function M._wait_for_msgs(self)
    assert(self._cb, '_wait_for_msgs can be called only from _start')
    while true do
        local msg = self._pending_queue:get()
        fiber.yield()
        if msg ~= nil then
            self._pending_size = self._pending_size - #msg.payload
            self._cb(msg)
        end
        if self._max_msgs > 0 and self._received >= self._max_msgs and self._pending_queue:is_empty() then
            self:_stop_processing()
        end
    end
end


return M
