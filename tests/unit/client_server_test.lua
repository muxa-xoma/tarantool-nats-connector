local t = require('luatest')

local helper = require('tests.helpers.unit')


local server = require('nats.client.server')


local group =  t.group('module-client-server')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)


group.test_new = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_type(module, 'table')
    t.assert_type(module.uri, 'table')
    t.assert_equals(module.uri.scheme, 'nats')
    t.assert_equals(module.uri.service, '4222')
    t.assert_equals(module.uri.host, 'nats-1')
    t.assert_equals(module.reconnects, 0)
    t.assert_not(module.did_connect)
    t.assert_not(module.discovered)
    t.assert_not(module.info)
    t.assert_not(module.tls_name)
    t.assert_type(module.new, 'function')
    t.assert_type(module.set_server_info, 'function')
    t.assert_type(module.set_tls_name, 'function')
    t.assert_type(module.need_connecting, 'function')
    t.assert_type(module.server_discovered, 'function')
    t.assert_type(module.server_version, 'function')
end

group.test_set_server_info = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_not(module.info)
    local info_s = '{"server_id":"Zk0GQ3JBSrg3oyxCRRlE09","server_name":"Zk0GQ3JBSrg3oyxCRRlE09","headers":true,"version":"1.2.0","proto":1,"go":"go1.10.3","host":"0.0.0.0","port":4222,"max_payload":1048576,"client_id":2392}'
    module:set_server_info(info_s)
    t.assert(module.info)
    t.assert_type(module.info, 'table')
    t.assert_equals(module.info.server_id, "Zk0GQ3JBSrg3oyxCRRlE09")
    t.assert_equals(module.info.server_name, "Zk0GQ3JBSrg3oyxCRRlE09")
    t.assert(module.info.headers)
    t.assert_equals(module.info.version.major, 1)
    t.assert_equals(module.info.version.minor, 2)
    t.assert_equals(module.info.version.patch, 0)
    t.assert_equals(module.info.proto, 1)
    t.assert_equals(module.info.go.major, 1)
    t.assert_equals(module.info.go.minor, 10)
    t.assert_equals(module.info.go.patch, 3)
    t.assert_equals(module.info.host, "0.0.0.0")
    t.assert_equals(module.info.port, 4222)
    t.assert_equals(module.info.max_payload, 1048576)
    t.assert_equals(module.info.client_id, 2392)
end

group.test_set_tls_name = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_not(module.tls_name)
    local tls_name_s = 'nats'
    module:set_tls_name(tls_name_s)
    t.assert_equals(module.tls_name, tls_name_s)
end

group.test_need_connecting = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_not(module.did_connect)
    module:need_connecting()
    t.assert(module.did_connect)
end

group.test_server_discovered = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_not(module.discovered)
    module:server_discovered()
    t.assert(module.discovered)
end

group.test_server_version_unknown = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    t.assert_not(module.info)
    t.assert_equals('Unknown version for NATS server', module:server_version())
end

group.test_server_version = function()
    local url = 'nats://nats-1:4222'
    local module = server.new(url)
    local info_s = '{"server_id":"Zk0GQ3JBSrg3oyxCRRlE09","server_name":"Zk0GQ3JBSrg3oyxCRRlE09","headers":true,"version":"1.2.0","proto":1,"go":"go1.10.3","host":"0.0.0.0","port":4222,"max_payload":1048576,"client_id":2392}'
    module:set_server_info(info_s)
    t.assert(module.info)
    t.assert_equals('NATS server 1.2.0 on golang go1.10.3', module:server_version())
end
