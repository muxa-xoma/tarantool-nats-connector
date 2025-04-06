local math = require('math')

math.randomseed(os.time())

---@class TestHelper
---@field data_dir string directory for tarantool files
local M = {
    data_dir = '/tmp/tests',
    start_random = 5,
    end_random = 15
}
M.__index = M

---@return TestHelper class instance
function M.new()
    ---@type TestHelper
    local self = setmetatable({}, M)
    return self
end

---@param self TestHelper class instance
---@param start_random number what date to start sampling from
---@param end_random number what number to end the sample with
function M.random_int(self, start_random, end_random)
    start_random = start_random or self.start_random
    end_random = end_random or self.end_random
    return math.random(start_random, end_random)
end

---@param self TestHelper class instance
---@param len number string length
---@return string random string
function M.random_string(self, len)
    len = len or self:random_int()
    local chars = {{'1', '2', '3', '4', '5', '6', '7', '8', '9', '0'}, {' ', '. ', ', ', ' - '}}
    local result = ''
    local count = 0
    while count < len do
        local add = string.char(self:random_int(97, 97 + 25))
        local up = self:random_int(1, 2)
        if up == 1 then
            add = add:upper()
        end
        if len - count > 4 then
            local add_char = self:random_int(1, 2)
            if add_char == 1 then
                local lst = chars[self:random_int(1, 2)]
                add = add .. lst[self:random_int(1, #lst)]
            end
        end
        result = result .. add
        count = count + #add
    end
    return result
end

return M
