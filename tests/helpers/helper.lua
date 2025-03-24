local math = require('math')

math.randomseed(os.time())

local M = {}
M.__index = M

function M.new()
    local self = setmetatable({}, M)
    self.datadir = '/tmp/tests'
    self.random_int = math.random
    return self
end


function M.random_string(self, len)
    local chars = {{'1', '2', '3', '4', '5', '6', '7', '8', '9', '0'}, {' ', '. ', ', ', ' - '}}
    local result = ''
    local count = 0
    while count < len do
        local add = string.char(self.random_int(97, 97 + 25))
        local up = self.random_int(1, 2)
        if up == 1 then
            add = add:upper()
        end
        if len - count > 4 then
            local add_char = self.random_int(1, 2)
            if add_char == 1 then
                local lst = chars[self.random_int(1, 2)]
                add = add .. lst[self.random_int(1, #lst)]
            end
        end
        result = result .. add
        count = count + #add
    end
    return result
end

return M.new()
