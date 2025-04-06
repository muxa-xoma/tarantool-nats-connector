local t = require('luatest')
local fio = require('fio')

local helper = require('tests.helpers.helper').new()

t.before_suite(function()
    fio.mktree(helper.data_dir)
    box.cfg({ work_dir = helper.data_dir })
end)

t.after_suite(function()
    fio.rmtree(helper.data_dir)
end)

return helper
