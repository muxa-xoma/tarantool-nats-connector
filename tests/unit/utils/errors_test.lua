local t = require('luatest')

local helper = require('tests.helpers.unit')

local NatsErrorEnum = require('nats.utils.errors')


local group =  t.group('utils-enum-errors')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_types = function()
    for _, v in pairs(NatsErrorEnum) do
        t.assert_type(v.code, 'number')
        t.assert_type(v.message, 'string')
        t.assert_type(v.type, 'string')
    end
end

group.test_values = function()
    for _, v in pairs(NatsErrorEnum) do
        t.assert_gt(v.code, 0)
        t.assert_le(v.code, 80)
        if v.code <= 50 then
            t.assert_equals(v.type, 'NATS connector')
        else
            t.assert_equals(v.type, 'NATS server')
        end
    end
end

group.test_raise = function()
    local function raise(err)
        error(err)
    end
    for k, v in pairs(NatsErrorEnum) do
        t.assert_error(raise, NatsErrorEnum[k])
        t.assert_error_msg_equals(v, raise, NatsErrorEnum[k])
    end
end
