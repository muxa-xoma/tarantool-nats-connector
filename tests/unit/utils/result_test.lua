local t = require('luatest')

local helper = require('tests.helpers.unit')

local result_module = require('nats.utils.result')


local group =  t.group('utils-module-result')

group.before_all(
        function(cg)
            cg.helper = helper
            ---@type Result
            cg.module = result_module
        end
)

group.test_new_data = function(cg)
    local data = cg.helper:random_string(cg.helper:random_int(5, 50))
    ---@type Result
    local result = cg.module.new(data)
    t.assert(result.success)
    t.assert_equals(result.data, data)
    t.assert_not(result.error)
end

group.test_new_err = function(cg)
    local err = {
        message = cg.helper:random_string(cg.helper:random_int(5, 50)),
        code = 777,
        type = 'Test type'
    }
    ---@type Result
    local result = cg.module.new(nil, err)
    t.assert_not(result.success)
    t.assert_not(result.data)
    t.assert_equals(result.error, err)
end

group.test_new_err_add_err_text = function(cg)
    local err = {
        message = cg.helper:random_string(cg.helper:random_int(5, 50)) .. ': ',
        code = 888,
        type = 'Test type add error text'
    }
    local add_err_text = cg.helper:random_string(cg.helper:random_int(5, 50))
    ---@type Result
    local result = cg.module.new(nil, err, add_err_text)
    t.assert_not(result.success)
    t.assert_not(result.data)
    t.assert_equals(result.error.code, err.code)
    t.assert_equals(result.error.type, err.type)
    t.assert_equals(result.error.message, err.message .. add_err_text)
end
