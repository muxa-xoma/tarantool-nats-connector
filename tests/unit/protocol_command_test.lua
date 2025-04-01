local t = require('luatest')

local helper = require('tests.helpers.unit')

local command = require('nats.protocol.command')
local nuid = require('nats.utils.nuid')


local group =  t.group('module-protocol-command')

group.before_all(
        function(cg)
            cg.helper = helper
            cg.module = command.new()
            cg.nuid = nuid.new()
        end
)


group.test_new = function()
    local module = command.new()
    t.assert_type(module, 'table')
    t.assert_equals(module._delimiter, '\r\n')
    t.assert_equals(module._headers, 'NATS/1.0')
    t.assert_equals(module._connect, 'CONNECT')
    t.assert_equals(module._pub, 'PUB')
    t.assert_equals(module._hpub, 'HPUB')
    t.assert_equals(module._sub, 'SUB')
    t.assert_equals(module._unsub, 'UNSUB')
    t.assert_equals(module._ping, 'PING')
    t.assert_equals(module._pong, 'PONG')
    t.assert_type(module.new, 'function')
    t.assert_type(module.connect, 'function')
    t.assert_type(module.publish, 'function')
    t.assert_type(module.headers_publish, 'function')
    t.assert_type(module.subscribe, 'function')
    t.assert_type(module.unsubscribe, 'function')
    t.assert_type(module.ping, 'function')
    t.assert_type(module.pong, 'function')
end

group.test_publish_without_reply_subject = function(cg)
    local subject = cg.nuid:next()
    local payload = cg.helper:random_string(cg.helper.random_int(10, 50))
    local result = cg.module:publish(subject, payload)
    t.assert_equals('PUB ' .. subject .. ' ' .. #payload .. '\r\n' .. payload .. '\r\n', result)
end

group.test_publish_with_reply_subject = function(cg)
    local subject = cg.nuid:next()
    local payload = cg.helper:random_string(cg.helper.random_int(10, 50))
    local reply_subject = cg.nuid:next()
    local result = cg.module:publish(subject, payload, reply_subject)
    t.assert_equals('PUB ' .. subject .. ' ' .. reply_subject .. ' ' .. #payload .. '\r\n' .. payload .. '\r\n', result)
end

group.test_headers_publish_without_reply_subject = function(cg)
    local subject = cg.nuid:next()
    local payload = cg.helper:random_string(cg.helper.random_int(10, 50))
    local headers = {
        test = 'test',
        pretest = '15'
    }
    local result = cg.module:headers_publish(subject, payload, headers)
    local headers_s = 'NATS/1.0' .. '\r\n' .. 'test: test' .. '\r\n' .. 'pretest: 15' .. '\r\n' .. '\r\n'
    t.assert_equals('HPUB ' .. subject .. ' ' .. #headers_s .. ' ' .. #headers_s + #payload ..
            '\r\n' .. headers_s .. payload .. '\r\n', result)
end

group.test_headers_publish_with_reply_subject = function(cg)
    local subject = cg.nuid:next()
    local payload = cg.helper:random_string(cg.helper.random_int(10, 50))
    local reply_subject = cg.nuid:next()
    local headers = {
        string = 'value',
        int = '15',
        bol = 'false'
    }
    local result = cg.module:headers_publish(subject, payload, headers, reply_subject)
    local headers_s = 'NATS/1.0' .. '\r\n' .. 'bol: false' .. '\r\n' .. 'string: value' .. '\r\n' .. 'int: 15' .. '\r\n' .. '\r\n'
    t.assert_equals('HPUB ' .. subject .. ' ' .. reply_subject .. ' ' .. #headers_s .. ' ' .. #headers_s + #payload ..
            '\r\n' .. headers_s .. payload .. '\r\n', result)
end

group.test_subscribe_without_group = function(cg)
    local subject = cg.nuid:next()
    local sid = cg.helper.random_int(1, 50)
    local result = cg.module:subscribe(subject, sid)
    t.assert_equals('SUB ' .. subject .. ' ' .. sid .. '\r\n' , result)
end

group.test_subscribe_with_group = function(cg)
    local subject = cg.nuid:next()
    local sid = cg.helper.random_int(1, 50)
    local grp = cg.nuid:next()
    local result = cg.module:subscribe(subject, sid, grp)
    t.assert_equals('SUB ' .. subject .. ' ' .. grp .. ' ' .. sid .. '\r\n' , result)
end

group.test_unsubscribe_without_max_msg = function(cg)
    local sid = cg.helper.random_int(1, 50)
    local result = cg.module:unsubscribe(sid)
    t.assert_equals('UNSUB ' .. sid .. '\r\n' , result)
end

group.test_unsubscribe_with_max_msg = function(cg)
    local sid = cg.helper.random_int(1, 50)
    local max_msg = cg.helper.random_int(1, 50)
    local result = cg.module:unsubscribe(sid, max_msg)
    t.assert_equals('UNSUB ' .. sid .. ' ' .. max_msg .. '\r\n' , result)
end

group.test_ping = function(cg)
    local result = cg.module:ping()
    t.assert_equals('PING' .. '\r\n' , result)
end

group.test_ping = function(cg)
    local result = cg.module:pong()
    t.assert_equals('PONG' .. '\r\n' , result)
end
