local t = require('luatest')
local fio = require('fio')

local helper = require('tests.helpers.helper')

t.before_suite(function()
    fio.mktree(helper.datadir)
    box.cfg({ work_dir = helper.datadir })
end)

t.after_suite(function()
    fio.rmtree(helper.datadir)
end)

return helper
