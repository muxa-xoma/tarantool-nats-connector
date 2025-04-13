local t = require('luatest')

local helper = require('tests.helpers.unit')


local parser = require('nats.protocol.parser')


local group =  t.group('module-protocol-parser')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)


group.test_new = function()
    local module = parser.new()
    t.assert_type(module, 'table')
    t.assert_equals(module._buffer, '')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._msg, {})
    t.assert_type(module.new, 'function')
    t.assert_type(module._reset, 'function')
    t.assert_type(module._parse_control_msg, 'function')
    t.assert_type(module._parse_msg_headers, 'function')
    t.assert_type(module.parse, 'function')
end

group.test_parse_control_msg_ping = function()
    local module = parser.new()
    local msg = 'PING'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 4)
    t.assert_equals(module._msg.type, msg)
end

group.test_parse_control_msg_pong = function()
    local module = parser.new()
    local msg = 'PONG'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 4)
    t.assert_equals(module._msg.type, msg)
end

group.test_parse_control_msg_ok = function()
    local module = parser.new()
    local msg = '+OK'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 4)
    t.assert_equals(module._msg.type, msg)
end

group.test_parse_control_msg_err = function()
    local module = parser.new()
    local msg = "-ERR 'Unknown Protocol Operation'"
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 4)
    t.assert_equals(module._msg.type, '-ERR')
    t.assert_equals(module._msg.payload, "'Unknown Protocol Operation'")
end

group.test_parse_control_msg_info = function()
    local module = parser.new()
    local msg = 'INFO {"server_id":"Zk0GQ3JBSrg3oyxCRRlE09","version":"1.2.0","proto":1,"go":"go1.10.3","host":"0.0.0.0","port":4222,"max_payload":1048576,"client_id":2392}'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 4)
    t.assert_equals(module._msg.type, 'INFO')
    t.assert_equals(module._msg.payload, '{"server_id":"Zk0GQ3JBSrg3oyxCRRlE09","version":"1.2.0","proto":1,"go":"go1.10.3","host":"0.0.0.0","port":4222,"max_payload":1048576,"client_id":2392}')
end

group.test_parse_control_msg_msg_without_reply_subject = function()
    local module = parser.new()
    local msg = 'MSG FOO.BAR 9 11'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 3)
    t.assert_equals(module._msg.type, 'MSG')
    t.assert_equals(module._msg.subject, 'FOO.BAR')
    t.assert_equals(module._msg.sid, 9)
    t.assert_equals(module._msg.payload_len, 11)
end

group.test_parse_control_msg_msg_with_reply_subject = function()
    local module = parser.new()
    local msg = 'MSG FOO.BAR 9 GREETING.34 11'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 3)
    t.assert_equals(module._msg.type, 'MSG')
    t.assert_equals(module._msg.subject, 'FOO.BAR')
    t.assert_equals(module._msg.sid, 9)
    t.assert_equals(module._msg.reply_subject, 'GREETING.34')
    t.assert_equals(module._msg.payload_len, 11)
end

group.test_parse_control_msg_hmsg_without_reply_subject = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 34 45'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 2)
    t.assert_equals(module._msg.type, 'HMSG')
    t.assert_equals(module._msg.subject, 'FOO.BAR')
    t.assert_equals(module._msg.sid, 9)
    t.assert_equals(module._msg.headers_len, 34)
    t.assert_equals(module._msg.payload_len, 11)
end

group.test_parse_control_msg_hmsg_with_reply_subject = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 BAZ.69 34 45'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 2)
    t.assert_equals(module._msg.type, 'HMSG')
    t.assert_equals(module._msg.subject, 'FOO.BAR')
    t.assert_equals(module._msg.sid, 9)
    t.assert_equals(module._msg.reply_subject, 'BAZ.69')
    t.assert_equals(module._msg.headers_len, 34)
    t.assert_equals(module._msg.payload_len, 11)
end

group.test_parse_control_msg_error_reading = function()
    local module = parser.new()
    local msg = 'HMG FOO.BAR 9 BAZ.69 34 45'
    module:_parse_control_msg(msg)
    t.assert_equals(module._state, 5)
end

group.test_parse_msg_headers_one_header = function()
    local module = parser.new()
    local msg = 'NATS/1.0\r\nFoodGroup: vegetable\r\n\r\n'
    module:_parse_msg_headers(msg)
    t.assert_equals(module._state, 3)
    t.assert(module._msg.headers)
    t.assert(module._msg.headers.FoodGroup)
    t.assert_equals(module._msg.headers.FoodGroup, 'vegetable')
end

group.test_parse_msg_headers_two_header = function()
    local module = parser.new()
    local msg = 'NATS/1.0\r\nFoodGroup: vegetable\r\nItem: tomato\r\n\r\n'
    module:_parse_msg_headers(msg)
    t.assert_equals(module._state, 3)
    t.assert(module._msg.headers)
    t.assert(module._msg.headers.FoodGroup)
    t.assert_equals(module._msg.headers.FoodGroup, 'vegetable')
    t.assert(module._msg.headers.Item)
    t.assert_equals(module._msg.headers.Item, 'tomato')
end

group.test_parse_msg_headers_err = function()
    local module = parser.new()
    local msg = 'NATS/1.1\r\nFoodGroup: vegetable\r\n\r\n'
    module:_parse_msg_headers(msg)
    t.assert_equals(module._state, 5)
    t.assert_not(module._msg.headers)
end

group.test_parse_shoot_msg = function()
    local module = parser.new()
    local msg = 'PING\r\n'
    local result = module:parse(msg)
    t.assert(result.success)
    t.assert_equals(result.data.type, 'PING')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._buffer, '')
end

group.test_parse_msg_with_full_payload = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n'
    local result = module:parse(msg)
    t.assert(result.success)
    t.assert_equals(result.data.type, 'HMSG')
    t.assert_equals(result.data.subject, 'FOO.BAR')
    t.assert_equals(result.data.sid, 9)
    t.assert_equals(result.data.reply_subject, 'BAZ.69')
    t.assert_equals(result.data.headers_len, 34)
    t.assert_equals(result.data.payload_len, 11)
    t.assert(result.data.headers)
    t.assert(result.data.headers.FoodGroup)
    t.assert_equals(result.data.headers.FoodGroup, 'vegetable')
    t.assert_equals(result.data.payload, 'Hello World')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._buffer, '')
end

group.test_parse_msg_with_not_full_payload = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello'
    local msg_end = ' World\r\n'
    local result = module:parse(msg)
    t.assert_not(result.success)
    t.assert_equals(result.error.code, 7)
    result = module:parse(msg_end)
    t.assert(result.success)
    t.assert_equals(result.data.type, 'HMSG')
    t.assert_equals(result.data.subject, 'FOO.BAR')
    t.assert_equals(result.data.sid, 9)
    t.assert_equals(result.data.reply_subject, 'BAZ.69')
    t.assert_equals(result.data.headers_len, 34)
    t.assert_equals(result.data.payload_len, 11)
    t.assert(result.data.headers)
    t.assert(result.data.headers.FoodGroup)
    t.assert_equals(result.data.headers.FoodGroup, 'vegetable')
    t.assert_equals(result.data.payload, 'Hello World')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._buffer, '')
end

group.test_parse_msg_with_not_full_headers = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: '
    local msg_end = 'vegetable\r\n\r\nHello World\r\n'
    local result = module:parse(msg)
    t.assert_not(result.success)
    t.assert_equals(result.error.code, 7)
    result = module:parse(msg_end)
    t.assert(result.success)
    t.assert_equals(result.data.type, 'HMSG')
    t.assert_equals(result.data.subject, 'FOO.BAR')
    t.assert_equals(result.data.sid, 9)
    t.assert_equals(result.data.reply_subject, 'BAZ.69')
    t.assert_equals(result.data.headers_len, 34)
    t.assert_equals(result.data.payload_len, 11)
    t.assert(result.data.headers)
    t.assert(result.data.headers.FoodGroup)
    t.assert_equals(result.data.headers.FoodGroup, 'vegetable')
    t.assert_equals(result.data.payload, 'Hello World')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._buffer, '')
end

group.test_parse_msg_with_not_full_control_line = function()
    local module = parser.new()
    local msg = 'HMSG FOO.BAR 9 BAZ.6'
    local msg_end = '9 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n'
    local result = module:parse(msg)
    t.assert_not(result.success)
    t.assert_equals(result.error.code, 7)
    result = module:parse(msg_end)
    t.assert(result.success)
    t.assert_equals(result.data.type, 'HMSG')
    t.assert_equals(result.data.subject, 'FOO.BAR')
    t.assert_equals(result.data.sid, 9)
    t.assert_equals(result.data.reply_subject, 'BAZ.69')
    t.assert_equals(result.data.headers_len, 34)
    t.assert_equals(result.data.payload_len, 11)
    t.assert(result.data.headers)
    t.assert(result.data.headers.FoodGroup)
    t.assert_equals(result.data.headers.FoodGroup, 'vegetable')
    t.assert_equals(result.data.payload, 'Hello World')
    t.assert_equals(module._state, 1)
    t.assert_equals(module._buffer, '')
end

group.test_error_parse = function()
    local err_text_t = {
        'Unknown Protocol Operation', 'Attempted To Connect To Route Port', 'Authorization Violation',
        'Authorization Timeout', 'Invalid Client Protocol', 'Maximum Control Line Exceeded', 'Parser Error',
        'Secure Connection - TLS Required', 'Stale Connection', 'Maximum Connections Exceeded', 'Slow Consumer',
        'Maximum Payload Violation', 'Invalid Subject', 'Permissions Violation for Subscription to test.topic',
        'Permissions Violation for Publish to subjects.test.1', 'Server unexpected error'
    }
    local module = parser.new()
    for _, v in ipairs(err_text_t) do
        local err = module.error_parse(v)
        t.assert_type(err, 'table')
        t.assert_equals(err.type, 'NATS server')
        t.assert_gt(err.code, 50)
        t.assert_le(err.code, 80)
    end
end
