local t = require('luatest')
local json =require('json')

local helper = require('tests.helpers.unit')

local NatsConnectionParameters = require('nats.protocol.connection_parameters')
local NatsServerInfo = require('nats.protocol.server_info')
local versions = require('nats.version')
local Version = require('nats.utils.version')


local group =  t.group('module-protocol-connection_parameters')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_new_defaults = function()
    local module = NatsConnectionParameters.new()
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    t.assert_equals(module.verbose, false)
    t.assert_equals(module.pedantic, false)
    t.assert_equals(module.tls_required, false)
    t.assert_equals(module.lang:tostring(), lang:tostring())
    t.assert_equals(module.version:tostring(), module_version:tostring())
    t.assert(module.echo)
    t.assert_equals(module.name, nil)
    t.assert_equals(module.auth_token, nil)
    t.assert_equals(module.user, nil)
    t.assert_equals(module.pass, nil)
    t.assert_equals(module.protocol, nil)
    t.assert_equals(module.sig, nil)
    t.assert_equals(module.jwt, nil)
    t.assert(module.no_responders)
    t.assert(module.headers)
    t.assert_equals(module.nkey, nil)
end

group.test_new_all_params = function(cg)
    local name = cg.helper:random_string(cg.helper:random_int(5, 10))
    local user = cg.helper:random_string(cg.helper:random_int(10, 15))
    local password = cg.helper:random_string(cg.helper:random_int(10, 15))
    local auth_token = cg.helper:random_string(cg.helper:random_int(50, 100))
    local jwt = cg.helper:random_string(cg.helper:random_int(100, 200))
    local nkey = cg.helper:random_string(cg.helper:random_int(100, 200))
    local module = NatsConnectionParameters.new(
            name, user, password, auth_token, jwt, nkey,
            false, false, true, true, true
    )
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    t.assert_equals(module.verbose, true)
    t.assert_equals(module.pedantic, true)
    t.assert_equals(module.tls_required, true)
    t.assert_equals(module.lang:tostring(), lang:tostring())
    t.assert_equals(module.version:tostring(), module_version:tostring())
    t.assert_not(module.echo)
    t.assert_equals(module.name, name)
    t.assert_equals(module.auth_token, auth_token)
    t.assert_equals(module.user, user)
    t.assert_equals(module.pass, password)
    t.assert_equals(module.protocol, nil)
    t.assert_equals(module.sig, nil)
    t.assert_equals(module.jwt, jwt)
    t.assert_not(module.no_responders)
    t.assert(module.headers)
    t.assert_equals(module.nkey, nkey)
end

group.test_tostring_defaults = function()
    local module = NatsConnectionParameters.new()
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    local result_module = module:tostring()
    t.assert(result_module.success)
    local result = json.decode(result_module.data)
    t.assert_equals(result.verbose, false)
    t.assert_equals(result.pedantic, false)
    t.assert_equals(result.tls_required, false)
    t.assert_equals(result.lang, 'tarantool:' .. lang:tostring())
    t.assert_equals(result.version, module_version:tostring())
    t.assert(result.echo)
    t.assert_equals(result.name, nil)
    t.assert_equals(result.auth_token, nil)
    t.assert_equals(result.user, nil)
    t.assert_equals(result.pass, nil)
    t.assert_equals(result.protocol, nil)
    t.assert_equals(result.sig, nil)
    t.assert_equals(result.jwt, nil)
    t.assert(result.no_responders)
    t.assert(result.headers)
    t.assert_equals(result.nkey, nil)
end

group.test_new_all_params = function(cg)
    local name = cg.helper:random_string(cg.helper:random_int(5, 10))
    local user = cg.helper:random_string(cg.helper:random_int(10, 15))
    local password = cg.helper:random_string(cg.helper:random_int(10, 15))
    local auth_token = cg.helper:random_string(cg.helper:random_int(50, 100))
    local jwt = cg.helper:random_string(cg.helper:random_int(100, 200))
    local nkey = cg.helper:random_string(cg.helper:random_int(100, 200))
    local module = NatsConnectionParameters.new(
            name, user, password, auth_token, jwt, nkey,
            false, false, true, true, true
    )
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    local result_module = module:tostring()
    t.assert(result_module.success)
    local result = json.decode(result_module.data)
    t.assert_equals(result.verbose, true)
    t.assert_equals(result.pedantic, true)
    t.assert_equals(result.tls_required, true)
    t.assert_equals(result.lang, 'tarantool:' .. lang:tostring())
    t.assert_equals(result.version, module_version:tostring())
    t.assert_not(result.echo)
    t.assert_equals(result.name, name)
    t.assert_equals(result.auth_token, auth_token)
    t.assert_equals(result.user, user)
    t.assert_equals(result.pass, password)
    t.assert_equals(result.protocol, nil)
    t.assert_equals(result.sig, nil)
    t.assert_equals(result.jwt, jwt)
    t.assert_not(result.no_responders)
    t.assert(result.headers)
    t.assert_equals(result.nkey, nkey)
end

group.test_set_server_info_params_defaults = function()
    local module = NatsConnectionParameters.new()
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert(result_module.success)
    local result = json.decode(result_module.data)
    t.assert_equals(result.verbose, false)
    t.assert_equals(result.pedantic, false)
    t.assert_equals(result.tls_required, false)
    t.assert_equals(result.lang, 'tarantool:' .. lang:tostring())
    t.assert_equals(result.version, module_version:tostring())
    t.assert(result.echo)
    t.assert_equals(result.name, nil)
    t.assert_equals(result.auth_token, nil)
    t.assert_equals(result.user, nil)
    t.assert_equals(result.pass, nil)
    t.assert_equals(result.protocol, 1)
    t.assert_equals(result.sig, "CONNECT STRING")
    t.assert_equals(result.jwt, nil)
    t.assert(result.no_responders)
    t.assert(result.headers)
end

group.test_set_server_info_params_echo_error = function()
    local module = NatsConnectionParameters.new(nil, nil, nil, nil, nil, nil, false)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 0,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert_not(result_module.success)
    t.assert_equals(result_module.error.code, 1)
    t.assert_equals(result_module.error.message, 'Invalid connection parameters' .. ': server does not support disabling echo parameter')
end

group.test_set_server_info_params_not_user_error = function()
    local module = NatsConnectionParameters.new(nil, nil, 'secret password', nil)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576,
        "auth_required": true
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert_not(result_module.success)
    t.assert_equals(result_module.error.code, 1)
    t.assert_equals(result_module.error.message, 'Invalid connection parameters' .. ': server only supports authorized connections')
end

group.test_set_server_info_params_not_password_error = function()
    local module = NatsConnectionParameters.new(nil, 'service user', nil, nil)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576,
        "auth_required": true
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert_not(result_module.success)
    t.assert_equals(result_module.error.code, 1)
    t.assert_equals(result_module.error.message, 'Invalid connection parameters' .. ': server only supports authorized connections')
end

group.test_set_server_info_params_not_auth_token_error = function()
    local module = NatsConnectionParameters.new(nil, nil, nil, nil)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576,
        "auth_required": true
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert_not(result_module.success)
    t.assert_equals(result_module.error.code, 1)
    t.assert_equals(result_module.error.message, 'Invalid connection parameters' .. ': server only supports authorized connections')
end

group.test_set_server_info_params_auth_token = function()
    local module = NatsConnectionParameters.new(nil, nil, nil, helper:random_string(helper:random_int(50, 10)))
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576,
        "auth_required": true
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert(result_module.success)
end

group.test_set_server_info_params_auth_token = function()
    local module = NatsConnectionParameters.new(nil, 'service user', 'secret password', nil)
    ---@language "JSON"
    local server_info_s = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "nonce": "CONNECT STRING",
        "max_payload": 1048576,
        "auth_required": true
    }
    ]]
    local server_info = NatsServerInfo.new(server_info_s)
    local result_module = module:set_server_info_params(server_info)
    t.assert(result_module.success)
end
