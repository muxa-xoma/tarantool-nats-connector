local t = require('luatest')

local helper = require('tests.helpers.unit')

local version = require('nats.utils.version')


local group =  t.group('utils-module-version')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_new_release = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local module = version.new(table.concat({ major, minor, patch }, '.'))
    t.assert_equals(module.prefix, '')
    t.assert_equals(module.major, major)
    t.assert_equals(module.minor, minor)
    t.assert_equals(module.patch, patch)
    t.assert_not(module.pre_release)
    t.assert_not(module.hash)
end

group.test_new_release_with_prefix = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local module = version.new('v' .. table.concat({ major, minor, patch }, '.'))
    t.assert_equals(module.prefix, 'v')
    t.assert_equals(module.major, major)
    t.assert_equals(module.minor, minor)
    t.assert_equals(module.patch, patch)
    t.assert_not(module.pre_release)
    t.assert_not(module.hash)
end

group.test_new_release_candidate = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local pre_release = cg.helper.random_int(1, 10)
    local module = version.new(
            table.concat({ major, minor, patch }, '.') .. '-rc' .. tostring(pre_release)
    )
    t.assert_equals(module.prefix, '')
    t.assert_equals(module.major, major)
    t.assert_equals(module.minor, minor)
    t.assert_equals(module.patch, patch)
    t.assert_equals(module.pre_release, pre_release)
    t.assert_not(module.hash)
end

group.test_new_release_candidate_with_prefix = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local pre_release = cg.helper.random_int(1, 10)
    local module = version.new(
            'v' .. table.concat({ major, minor, patch }, '.') .. '-rc.' .. tostring(pre_release)
    )
    t.assert_equals(module.prefix, 'v')
    t.assert_equals(module.major, major)
    t.assert_equals(module.minor, minor)
    t.assert_equals(module.patch, patch)
    t.assert_equals(module.pre_release, pre_release)
    t.assert_not(module.hash)
end

group.test_new_release_with_pre_release_and_hash = function()
    local ver = '3.3.1-0-g91caac353f6'
    local major = 3
    local minor = 3
    local patch = 1
    local pre_release = 0
    local hash = 'g91caac353f6'
    local module = version.new(ver)
    t.assert_equals(module.prefix, '')
    t.assert_equals(module.major, major)
    t.assert_equals(module.minor, minor)
    t.assert_equals(module.patch, patch)
    t.assert_equals(module.pre_release, pre_release)
    t.assert_equals(module.hash, hash)
end

group.test_tostring_release = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local ver = table.concat({ major, minor, patch }, '.')
    local module = version.new(ver)
    local check_ver = module:tostring()
    t.assert_equals(ver, check_ver)
end

group.test_tostring_release_with_prefix = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local ver = 'v' .. table.concat({ major, minor, patch }, '.')
    local module = version.new(ver)
    local check_ver = module:tostring()
    t.assert_equals(ver, check_ver)
end

group.test_tostring_release_candidate = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local pre_release = cg.helper.random_int(1, 10)
    local ver = table.concat({ major, minor, patch }, '.') .. '-rc' .. tostring(pre_release)
    local module = version.new(ver)
    local check_ver = module:tostring()
    t.assert_equals(ver, check_ver)
end

group.test_tostring_release_candidate_with_prefix = function(cg)
    local major = cg.helper.random_int(1, 10)
    local minor = cg.helper.random_int(1, 10)
    local patch = cg.helper.random_int(1, 10)
    local pre_release = cg.helper.random_int(1, 10)
    local module_ver = 'v' .. table.concat({ major, minor, patch }, '.') .. '-rc.' .. tostring(pre_release)
    local ver = 'v' .. table.concat({ major, minor, patch }, '.') .. '-rc' .. tostring(pre_release)
    local module = version.new(module_ver)
    local check_ver = module:tostring()
    t.assert_equals(ver, check_ver)
end

group.test_tostring_release_with_pre_release_and_hash = function()
    local ver = '3.3.1-0-g91caac353f6'
    local module = version.new(ver)
    local check_ver = module:tostring()
    t.assert_equals(ver, check_ver)
end
