local t = require('luatest')
local group =  t.group('class-errors')

local helper = require('tests.helpers.unit')

local errors = require('nats.errors')


group.test_types = function()
    for _, v in pairs(errors) do
        t.assert_type(v.code, 'number')
        t.assert_type(v.message, 'string')
        t.assert_type(v.type, 'string')
    end
end

group.test_values = function()
    for _, v in pairs(errors) do
        t.assert_gt(v.code, 600)
        t.assert_lt(v.code, 650)
        t.assert_equals(v.type, 'NATS connector')
    end
end

group.test_raise = function()
    local function raise(err)
        err:raise()
    end
    for k, v in pairs(errors) do
        t.assert_error(raise, errors[k])
        t.assert_error_msg_equals(v.message, raise, errors[k])
    end
end
