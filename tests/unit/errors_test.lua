local t = require('luatest')

local helper = require('tests.helpers.unit')

local errors = require('nats.utils.errors')


local group =  t.group('enum-errors')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_types = function()
    for _, v in pairs(errors) do
        t.assert_type(v.code, 'number')
        t.assert_type(v.message, 'string')
        t.assert_type(v.type, 'string')
    end
end

group.test_values = function()
    for _, v in pairs(errors) do
        t.assert_gt(v.code, 0)
        t.assert_le(v.code, 50)
        t.assert_equals(v.type, 'NATS connector')
    end
end

group.test_raise = function()
    local function raise(err)
        error(err)
    end
    for k, v in pairs(errors) do
        t.assert_error(raise, errors[k])
        t.assert_error_msg_equals(v, raise, errors[k])
    end
end
