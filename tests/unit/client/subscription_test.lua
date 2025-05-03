local t = require('luatest')
local fiber = require('fiber')
local json = require('json')

local helper = require('tests.helpers.unit')


local Subscription = require('nats.client.subscription')
local NatsErrorEnum = require('nats.utils.errors')


local group =  t.group('module-client-subscription')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.before_each(
        function(cg)
            cg.client = {
                is_closed = function() return false  end,
                is_draining = function() return false  end,
                _send_unsubscribe = function() return nil end,
                flush = function() return nil end,
                _remove_sub = function() return nil end,
                is_reconnecting = function() return false  end,
                _cb = {
                    error_cb = function(err) print(json.encode(err)) end
                }
            }
            cg.id = cg.helper:random_int(1, 50)
            cg.subject = cg.helper:random_string(cg.helper:random_int(5, 10))
            cg.queue = cg.helper:random_string(cg.helper:random_int(5, 10))
            cg.cb_f = function(msg)
                print(msg)
            end
            cg.max_msgs = cg.helper:random_int(1, 100)
            cg.module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
        end
)


group.test_new_default = function()
    local module = Subscription.new()
    t.assert_type(module, 'table')
    t.assert_not(module._client)
    t.assert_equals(module._id, 0)
    t.assert_equals(module._subject, '')
    t.assert_equals(module._queue, nil)
    t.assert_equals(module._max_msgs, 0)
    t.assert_equals(module._received, 0)
    t.assert_not(module._cb)
    t.assert_equals(module._closed, false)
    t.assert_equals(module._pending_msgs_limit, 512 * 1024)
    t.assert_equals(module._pending_bytes_limit, 128 * 1024 * 1024)
    t.assert(module._pending_queue)
    t.assert_equals(module._pending_size, 0)
end

group.test_new = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
    t.assert_type(module, 'table')
    t.assert_equals(module._client, cg.client)
    t.assert_equals(module._id, cg.id)
    t.assert_equals(module._subject, cg.subject)
    t.assert_equals(module._queue, cg.queue)
    t.assert_equals(module._max_msgs, cg.max_msgs)
    t.assert_equals(module._received, 0)
    t.assert_equals(module._cb, cg.cb_f)
    t.assert_equals(module._closed, false)
    t.assert_equals(module._pending_msgs_limit, 512 * 1024)
    t.assert_equals(module._pending_bytes_limit, 128 * 1024 * 1024)
    t.assert(module._pending_queue)
    t.assert_equals(module._pending_size, 0)
end

group.test_subject = function(cg)
    t.assert_equals(cg.subject, cg.module:subject())
end

group.test_queue = function(cg)
    t.assert_equals(cg.queue, cg.module:queue())
end

group.test_messages = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    module:_start()
    t.assert_type(module:messages(), 'function')
end

group.test_messages_error = function(cg)
    cg.module:_start()
    t.assert_error_msg_contains('cannot iterate over messages with a non iteration subscription type', cg.module.messages, cg.module)
end

group.test_pending_msgs_0 = function(cg)
    t.assert_equals(0, cg.module:pending_msgs())
end

group.test_pending_msgs_many = function(cg)
    local count = 20
    for i = 1, count, 1 do
        cg.module._pending_queue:put('test msg #' .. i)
    end
    t.assert_equals(count, cg.module:pending_msgs())
end

group.test_pending_bytes_0 = function(cg)
    t.assert_equals(0, cg.module:pending_bytes())
end

group.test_pending_bytes_many = function(cg)
    local count = 20
    local bytes = 0
    for i = 1, count, 1 do
        local msg = 'test msg #' .. i
        bytes = bytes + #msg
        cg.module._pending_size = cg.module._pending_size + #msg
    end
    t.assert_equals(bytes, cg.module:pending_bytes())
end

group.test_delivered_0 = function(cg)
    t.assert_equals(0, cg.module:delivered())
end

group.test_delivered_many = function(cg)
    local count = 20
    for _ = 1, count, 1 do
        cg.module._received = cg.module._received + 1
    end
    t.assert_equals(count, cg.module:delivered())
end

group.test_next_msg = function(cg)
    local msg = {
        payload = cg.helper:random_string(cg.helper:random_int(10, 50))
    }
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    module._pending_queue:put(msg)
    module._pending_size = module._pending_size + #msg.payload
    t.assert_equals(msg, module:next_msg(1))
    t.assert_equals(0, module:pending_bytes())
end

group.test_next_msg_timeout = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    t.assert_error_covers(NatsErrorEnum.timeout, module.next_msg, module, 0.5)
end

group.test_next_msg_cb = function(cg)
    t.assert_error_msg_contains('nats: next_msg cannot be used in async subscriptions', cg.module.next_msg, cg.module, 1)
end

group.test_start_cb = function(cg)
    cg.module:_start()
    t.assert_not(cg.module._message_iterator)
    t.assert(cg.module._wait_for_msgs_task)
    t.assert_equals(cg.module._wait_for_msgs_task:status(), 'suspended')
end

group.test_start_not_cb = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    module:_start()
    t.assert(module._message_iterator)
    t.assert_type(module._message_iterator, 'function')
    t.assert_not(cg.module._wait_for_msgs_task)
end

group.test_start_cb_not_func = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, 'cb_func', cg.max_msgs)
    t.assert_error_msg_contains('nats: must use function for subscriptions', module._start, module)
end

group.test_stop_processing_with_cb = function(cg)
    cg.module:_start()
    t.assert(cg.module._wait_for_msgs_task)
    t.assert(cg.module._wait_for_msgs_task:status() ~= 'dead')
    t.assert(cg.module._pending_queue)
    t.assert_not(cg.module._pending_queue:is_closed())
    cg.module:_stop_processing()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
end

group.test_stop_processing_without_cb = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    module:_start()
    t.assert_not(module._wait_for_msgs_task)
    t.assert(module._pending_queue)
    t.assert_not(module._pending_queue:is_closed())
    t.assert(module._message_iterator)
    t.assert_type(module._message_iterator, 'function')
    module:_stop_processing()
    fiber.yield()
    t.assert(module._pending_queue:is_closed())
    t.assert_not(module._message_iterator)
end

group.test__drain_cb_not_nil = function(cg)
    cg.module:_start()
    local count = 20
    for _ = 1, count, 1 do
        local msg = {
            payload = cg.helper:random_string(cg.helper:random_int(10, 50))
        }
        cg.module._pending_queue:put(msg)
        cg.module._pending_size = cg.module._pending_size + #msg.payload
    end
    cg.module:_drain()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
    t.assert(cg.module._closed)
end

group.test__drain_cb_nil = function(cg)
    local module = Subscription.new(cg.client, cg.id, cg.subject, cg.queue, nil, cg.max_msgs)
    module:_start()
    local count = 20
    for _ = 1, count, 1 do
        local msg = {
            payload = cg.helper:random_string(cg.helper:random_int(10, 50))
        }
        module._pending_queue:put(msg)
        module._pending_size = module._pending_size + #msg.payload
    end
    module:_drain()
    fiber.yield()
    t.assert(module._pending_queue:is_closed())
    t.assert_not(module._message_iterator)
    t.assert(module._closed)
end

group.test_drain = function(cg)
    cg.module:_start()
    cg.module:drain()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
    t.assert(cg.module._closed)
end

group.test_drain_self_closed = function(cg)
    cg.module:_start()
    cg.module:drain()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
    t.assert(cg.module._closed)
    t.assert_error_covers(NatsErrorEnum.bad_subscription, cg.module.drain, cg.module)
end

group.test_drain_client_closed = function(cg)
    local client = table.deepcopy(cg.client)
    client.is_closed = function() return true end
    local module = Subscription.new(client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
    module:_start()
    t.assert_error_covers(NatsErrorEnum.connection_closed, module.drain, module)
end

group.test_drain_client_draining = function(cg)
    local client = table.deepcopy(cg.client)
    client.is_draining = function() return true end
    local module = Subscription.new(client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
    module:_start()
    t.assert_error_covers(NatsErrorEnum.connection_draining, module.drain, module)
end

group.test_unsubscribe = function(cg)
    cg.module:_start()
    cg.module:unsubscribe()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
    t.assert(cg.module._closed)
end

group.test_unsubscribe_self_closed = function(cg)
    cg.module:_start()
    cg.module:unsubscribe()
    fiber.yield()
    t.assert(cg.module._wait_for_msgs_task:status() == 'dead')
    t.assert(cg.module._pending_queue:is_closed())
    t.assert(cg.module._closed)
    t.assert_error_covers(NatsErrorEnum.bad_subscription, cg.module.unsubscribe, cg.module)
end

group.test_unsubscribe_client_closed = function(cg)
    local client = table.deepcopy(cg.client)
    client.is_closed = function() return true end
    local module = Subscription.new(client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
    module:_start()
    t.assert_error_covers(NatsErrorEnum.connection_closed, module.unsubscribe, module)
end

group.test_unsubscribe_client_draining = function(cg)
    local client = table.deepcopy(cg.client)
    client.is_draining = function() return true end
    local module = Subscription.new(client, cg.id, cg.subject, cg.queue, cg.cb_f, cg.max_msgs)
    module:_start()
    t.assert_error_covers(NatsErrorEnum.connection_draining, module.unsubscribe, module)
end
