local t = require('luatest')

local helper = require('tests.helpers.unit')

local NatsServerInfo = require('nats.protocol.server_info')


local group =  t.group('module-protocol-server_info')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_new_required_params = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576
    }
    ]]
    local serv = NatsServerInfo.new(params)
    t.assert_equals(serv.server_id, 'NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI')
    t.assert_equals(serv.server_name, 'NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI')
    t.assert_equals(serv.version:tostring(), "2.10.24")
    t.assert_equals(serv.proto, 1)
    t.assert_equals(serv.go:tostring(), "1.23.4")
    t.assert_equals(serv.host, "0.0.0.0")
    t.assert_equals(serv.port, 4222)
    t.assert(serv.headers)
    t.assert_equals(serv.max_payload, 1048576)
end

group.test_new_all_params = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    local serv = NatsServerInfo.new(params)
    t.assert_equals(serv.server_id, 'NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI')
    t.assert_equals(serv.server_name, 'NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI')
    t.assert_equals(serv.version:tostring(), "2.10.24")
    t.assert_equals(serv.proto, 1)
    t.assert_equals(serv.go:tostring(), "1.23.4")
    t.assert_equals(serv.host, "0.0.0.0")
    t.assert_equals(serv.port, 4222)
    t.assert(serv.headers)
    t.assert_equals(serv.max_payload, 1048576)
    t.assert_equals(serv.client_id, 9)
    t.assert(serv.auth_required)
    t.assert(serv.tls_required)
    t.assert(serv.tls_verify)
    t.assert(serv.tls_available)
    local hosts = {}
    local ports = {}
    for _, v in ipairs(serv.connect_urls) do
        table.insert(hosts, v.host)
        table.insert(ports, v.service)
        if v.scheme ~= nil then
            t.assert('nats', v.scheme)
        end
    end
    t.assert_covers({ "nats-2", "nats-4", "192.168.0.6", "192.168.5.9" }, hosts)
    t.assert_covers({ "4333", "4879", "4356", "4333" }, ports)
    table.clear(hosts)
    for _, v in ipairs(serv.ws_connect_urls) do
        table.insert(hosts, v.host)
        if v.scheme ~= nil then
            t.assert(v.scheme == 'ws' or v.scheme == 'wss')
        end
    end
    t.assert_covers({ "nats-1", "nats-3", "192.168.0.5", "192.168.0.7" }, hosts)
    t.assert(serv.ldm)
    t.assert(serv.jetstream)
    t.assert_equals(serv.ip, "11.10.2.3")
    t.assert_equals(serv.client_ip, "11.10.2.2")
    t.assert_equals(serv.nonce, "CONNECT STRING")
    t.assert_equals(serv.cluster, "my_cluster")
    t.assert_equals(serv.domain, "local")
    t.assert_equals(serv.xkey, "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT")
end

group.test_new_assert_server_id = function()
    ---@language "JSON"
    local params = [[
    {
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter server_id', NatsServerInfo.new, params)
end

group.test_new_assert_server_name = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter server_name', NatsServerInfo.new, params)
end

group.test_new_assert_version = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter version', NatsServerInfo.new, params)
end

group.test_new_assert_go = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter go', NatsServerInfo.new, params)
end

group.test_new_assert_host = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter host', NatsServerInfo.new, params)
end

group.test_new_assert_port = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter port', NatsServerInfo.new, params)
end

group.test_new_assert_headers = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter headers', NatsServerInfo.new, params)
end

group.test_new_assert_max_payload = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "proto": 1,
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter max_payload', NatsServerInfo.new, params)
end

group.test_new_assert_proto = function()
    ---@language "JSON"
    local params = [[
    {
        "server_id": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "server_name": "NCTGVP7HFGZ4DNM4A5YRZGBKGOKTE2TXIXY4OGABCKTPO4WAQ6AN4HVI",
        "version": "2.10.24",
        "git_commit": "1d6f7ea",
        "go": "go1.23.4",
        "host": "0.0.0.0",
        "port": 4222,
        "headers": true,
        "max_payload": 1048576,
        "client_id":9,
        "auth_required": true,
        "tls_required": true,
        "tls_verify": true,
        "tls_available": true,
        "connect_urls": [ "nats-2:4333", "nats://nats-4:4879", "192.168.0.6:4356", "nats://192.168.5.9:4333" ],
        "ws_connect_urls": ["nats-1", "ws://nats-3", "192.168.0.5", "wss://192.168.0.7"],
        "ldm": true,
        "jetstream": true,
        "ip": "11.10.2.3",
        "client_ip": "11.10.2.2",
        "nonce": "CONNECT STRING",
        "cluster": "my_cluster",
        "domain": "local",
        "xkey": "XAEJI3N2P7X73BBDM6WNLN4E5L3CPR6A6JD2FAYURW3JPCAA3CHRVYWT"
    }
    ]]
    t.assert_error_msg_contains('In the message of type info there must be a parameter proto', NatsServerInfo.new, params)
end