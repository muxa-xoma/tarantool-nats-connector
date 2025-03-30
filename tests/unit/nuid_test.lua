local t = require('luatest')

local helper = require('tests.helpers.unit')

local nuid = require('nats.utils.nuid')


local group =  t.group('module-nuid')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.before_each(
        function(cg)
            cg.module = nuid.new()
        end
)

group.test_new_types = function(cg)
    t.assert_type(cg.module._seq, 'number')
    t.assert_type(cg.module._inc, 'number')
    t.assert_type(cg.module._prefix, 'string')
end

group.test_new_values = function(cg)
    t.assert_ge(cg.module._seq, 0)
    t.assert_le(cg.module._seq, 839299365868340224)
    t.assert_ge(cg.module._inc, 33)
    t.assert_le(cg.module._inc, 333)
    t.assert_equals(#cg.module._prefix, 12)
end

group.test_next_return_type = function(cg)
    t.assert_type(cg.module:next(), 'string')
end

group.test_next_not_equal = function(cg)
    local iteration_number = 100000
    for _ = 1, iteration_number, 1 do
        t.assert_not_equals(cg.module:next(), cg.module:next())
    end
end

group.test_next_reset_sequential = function(cg)
    local prefix = cg.module._prefix
    local seq = cg.module._seq
    cg.module._inc = 839299365868340224 - seq
    cg.module:next()
    t.assert_not_equals(prefix, cg.module._prefix)
    t.assert_not_equals(seq, cg.module._seq)
end
