local t = require('luatest')

local helper = require('tests.helpers.unit')


local message = require('nats.client.message')


local group =  t.group('module-client-message')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.before_each(
        function(cg)
            cg.client = {}
            cg.sid = cg.helper:random_int(1, 50)
            cg.subject = cg.helper:random_string(cg.helper:random_int(5, 10))
            cg.reply = cg.helper:random_string(cg.helper:random_int(5, 10))
            cg.payload = cg.helper:random_string(cg.helper:random_int(15, 100))
            cg.headers = {
                test1 = cg.helper:random_string(cg.helper:random_int(5, 10)),
                test2 = cg.helper:random_string(cg.helper:random_int(5, 10)),
                test3 = cg.helper:random_string(cg.helper:random_int(5, 10))
            }
            cg.module = message.new(cg.client, cg.sid, cg.subject, cg.reply, cg.payload, cg.headers)
        end
)


group.test_new_default = function()
    local module = message.new()
    t.assert_type(module, 'table')
    t.assert_not(module._client)
    t.assert_not(module._sid)
    t.assert_not(module.headers)
    t.assert_equals(module.subject, '')
    t.assert_equals(module.reply, '')
    t.assert_equals(module.payload, '')
end

group.test_new = function(cg)
    local module = message.new(cg.client, cg.sid, cg.subject, cg.reply, cg.payload, cg.headers)
    t.assert_type(module, 'table')
    t.assert_type(module._client, 'table')
    t.assert_equals(module._sid, cg.sid)
    t.assert_equals(module.subject, cg.subject)
    t.assert_equals(module.reply, cg.reply)
    t.assert_equals(module.payload, cg.payload)
    t.assert_equals(module.headers, cg.headers)
end

group.test_header = function(cg)
    t.assert_equals(cg.headers, cg.module:header())
end

group.test_sid = function(cg)
    t.assert_equals(cg.sid, cg.module:sid())
end

group.test_sid_error = function(cg)
    local module = message.new(cg.client, nil, cg.subject, cg.reply, cg.payload, cg.headers)
    t.assert_error_msg_contains('sid not set', module.sid, module)
end
