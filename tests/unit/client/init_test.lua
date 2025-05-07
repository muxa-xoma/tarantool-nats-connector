local t = require('luatest')
local uri = require('uri')
local json = require('json')
local fiber = require('fiber')

local helper = require('tests.helpers.unit')

local MockNatsServer = require('tests.helpers.mock_nats_server')

local NatsClient = require('nats').NatsClient
local NatsErrorEnum = require('nats.utils.errors')
local versions = require('nats.version')
local Version = require('nats.utils.version')
local NatsProtocolConstants = require('nats.protocol.constants')


local group =  t.group('module-client-init')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.before_each(
        function(cg)
            cg.module = table.deepcopy(NatsClient)
            cg.server_info = {
                server_id = "NDVPY3XMMVOEWRUXTT2ZPV2ESPCE4PDJDV5JU73SRE6QLMXUYC474GCA",
                server_name = "mock-nats-server",
                version = "2.10.24",
                proto = 1,
                git_commit = '1d6f7ea',
                go = "go1.23.4",
                headers = true,
                max_payload = 1048576,
                client_id = cg.helper:random_int(1, 100),
                xkey = 'XBWJS4XT2PKOAVOIKMH7HGF4U3RXJHKY7HBLY7ZUGPOMHTSZVDDCRSHL'
            }
        end
)

group.after_each(
        function(cg)
            if cg.mock_nats_server then
                cg.mock_nats_server:stop()
                cg.mock_nats_server = nil
            end
        end
)

group.test_setup_server_pool_string = function(cg)
    local self = {}
    cg.module._setup_server_pool(self, '127.0.0.1:4222')
    t.assert_equals(#self._server_pool, 1)
    t.assert_equals(self._server_pool[1].uri.host, '127.0.0.1')
    t.assert_equals(self._server_pool[1].uri.service, '4222')
    t.assert_not(self._server_pool[1].uri.scheme)
    t.assert_equals(self._server_pool[1].uri.ipv4, '127.0.0.1')
    self = {}
    cg.module._setup_server_pool(self, 'nats://localhost:4222')
    t.assert_equals(#self._server_pool, 1)
    t.assert_equals(self._server_pool[1].uri.host, 'localhost')
    t.assert_equals(self._server_pool[1].uri.service, '4222')
    t.assert_equals(self._server_pool[1].uri.scheme, 'nats')
    t.assert_not(self._server_pool[1].uri.ipv4)
end

group.test_setup_server_pool_table = function(cg)
    local self = {}
    cg.module._setup_server_pool(self, {'127.0.0.1:4222', 'nats://localhost:4223'})
    t.assert_equals(#self._server_pool, 2)
    t.assert_equals(self._server_pool[1].uri.host, '127.0.0.1')
    t.assert_equals(self._server_pool[1].uri.service, '4222')
    t.assert_not(self._server_pool[1].uri.scheme)
    t.assert_equals(self._server_pool[1].uri.ipv4, '127.0.0.1')
    t.assert_equals(self._server_pool[2].uri.host, 'localhost')
    t.assert_equals(self._server_pool[2].uri.service, '4223')
    t.assert_equals(self._server_pool[2].uri.scheme, 'nats')
    t.assert_not(self._server_pool[2].uri.ipv4)
end

group.test_setup_server_pool_not_table_not_string = function(cg)
    local self = {}
    t.assert_error_covers(NatsErrorEnum.invalid_connect_params, cg.module._setup_server_pool, self, 1568)
end

group.test_setup_server_pool_table_item_not_string = function(cg)
    local self = {}
    t.assert_error_covers(NatsErrorEnum.invalid_connect_params, cg.module._setup_server_pool, self, {'nats://localhost:4223', false})
end

group.test_shuffle_server_pool = function(cg)
    local serv_pool = {'nats://localhost:4223', 'nats://localhost:4224', 'nats://localhost:4225',
                       'nats://localhost:4226', 'nats://localhost:4227', 'nats://localhost:4228',
                       'nats://localhost:4229', 'nats://localhost:4230', 'nats://localhost:4231',
                       'nats://localhost:4232' }
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_shuffle_server_pool()
    t.assert_not_equals(serv_pool, cg.module._server_pool)
end

group.test_setup_client_options_nil = function(cg)
    cg.module:_setup_server_pool({'nats://localhost:4223'})
    cg.module:_setup_client_options(nil)
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    t.assert_type(cg.module._cb, 'table')
    t.assert_type(cg.module._cb.error_cb, 'function')
    t.assert_equals(cg.module._cb.disconnected_cb, nil)
    t.assert_equals(cg.module._cb.closed_cb, nil)
    t.assert_equals(cg.module._cb.discovered_server_cb, nil)
    t.assert_equals(cg.module._cb.reconnected_cb, nil)
    t.assert_type(cg.module._connection_params, 'table')
    t.assert_equals(cg.module._connection_params.verbose, false)
    t.assert_equals(cg.module._connection_params.pedantic, false)
    t.assert_equals(cg.module._connection_params.tls_required, false)
    t.assert_equals(cg.module._connection_params.lang:tostring(), lang:tostring())
    t.assert_equals(cg.module._connection_params.version:tostring(), module_version:tostring())
    t.assert(cg.module._connection_params.echo)
    t.assert_equals(cg.module._connection_params.name, nil)
    t.assert_equals(cg.module._connection_params.auth_token, nil)
    t.assert_equals(cg.module._connection_params.user, nil)
    t.assert_equals(cg.module._connection_params.pass, nil)
    t.assert_equals(cg.module._connection_params.protocol, nil)
    t.assert_equals(cg.module._connection_params.sig, nil)
    t.assert_equals(cg.module._connection_params.jwt, nil)
    t.assert(cg.module._connection_params.no_responders)
    t.assert(cg.module._connection_params.headers)
    t.assert_equals(cg.module._connection_params.nkey, nil)
    t.assert_type(cg.module._params, 'table')
    t.assert_equals(cg.module._params.allow_reconnect, true)
    t.assert_equals(cg.module._params.connect_timeout, 2)
    t.assert_equals(cg.module._params.reconnect_time_wait, 2)
    t.assert_equals(cg.module._params.max_reconnect_attempts, 60)
    t.assert_equals(cg.module._params.ping_interval, 120)
    t.assert_equals(cg.module._params.max_outstanding_pings, 2)
    t.assert_equals(cg.module._params.dont_randomize, false)
    t.assert_equals(cg.module._params.drain_timeout, 30)
    t.assert_equals(cg.module._params.inbox_prefix, '_INBOX')
    t.assert_equals(cg.module._params.pending_size, 2 * 1024 * 1024)
    t.assert_equals(cg.module._params.flush_timeout, 10)
    t.assert_equals(cg.module._params.flusher_queue_size, 1024)
end

group.test_setup_client_options_nil = function(cg)
    local options = {
        error_cb = function() end,
        disconnected_cb = function() end,
        closed_cb = function() end,
        discovered_server_cb = function() end,
        reconnected_cb = function() end,
        name = 'name',
        pedantic = true,
        verbose = true,
        allow_reconnect = false,
        connect_timeout = 1,
        reconnect_time_wait = 1,
        max_reconnect_attempts = 1,
        ping_interval = 1,
        max_outstanding_pings = 1,
        dont_randomize = true,
        no_echo = true,
        user = 'user',
        password = 'words',
        drain_timeout = 1,
        inbox_prefix = 'inbox_prefix',
        pending_size = 1,
        flush_timeout = 1,
        flusher_queue_size = 1
    }
    cg.module:_setup_server_pool({'nats://localhost:4223'})
    cg.module:_setup_client_options(options)
    local lang = Version.new(versions.tarantool)
    local module_version = Version.new(versions.module)
    t.assert_type(cg.module._cb, 'table')
    t.assert_equals(cg.module._cb.error_cb, options.error_cb)
    t.assert_equals(cg.module._cb.disconnected_cb, options.disconnected_cb)
    t.assert_equals(cg.module._cb.closed_cb, options.closed_cb)
    t.assert_equals(cg.module._cb.discovered_server_cb, options.discovered_server_cb)
    t.assert_equals(cg.module._cb.reconnected_cb, options.reconnected_cb)
    t.assert_type(cg.module._connection_params, 'table')
    t.assert_equals(cg.module._connection_params.verbose, options.verbose)
    t.assert_equals(cg.module._connection_params.pedantic, options.pedantic)
    t.assert_equals(cg.module._connection_params.tls_required, false)
    t.assert_equals(cg.module._connection_params.lang:tostring(), lang:tostring())
    t.assert_equals(cg.module._connection_params.version:tostring(), module_version:tostring())
    t.assert_equals(cg.module._connection_params.echo, not options.no_echo)
    t.assert_equals(cg.module._connection_params.name, options.name)
    t.assert_equals(cg.module._connection_params.auth_token, nil)
    t.assert_equals(cg.module._connection_params.user, options.user)
    t.assert_equals(cg.module._connection_params.pass, options.password)
    t.assert_equals(cg.module._connection_params.protocol, nil)
    t.assert_equals(cg.module._connection_params.sig, nil)
    t.assert_equals(cg.module._connection_params.jwt, nil)
    t.assert(cg.module._connection_params.no_responders)
    t.assert(cg.module._connection_params.headers)
    t.assert_equals(cg.module._connection_params.nkey, nil)
    t.assert_type(cg.module._params, 'table')
    t.assert_equals(cg.module._params.allow_reconnect, options.allow_reconnect)
    t.assert_equals(cg.module._params.connect_timeout, options.connect_timeout)
    t.assert_equals(cg.module._params.reconnect_time_wait, options.reconnect_time_wait)
    t.assert_equals(cg.module._params.max_reconnect_attempts, options.max_reconnect_attempts)
    t.assert_equals(cg.module._params.ping_interval, options.ping_interval)
    t.assert_equals(cg.module._params.max_outstanding_pings, options.max_outstanding_pings)
    t.assert_equals(cg.module._params.dont_randomize, options.dont_randomize)
    t.assert_equals(cg.module._params.drain_timeout, options.drain_timeout)
    t.assert_equals(cg.module._params.inbox_prefix, options.inbox_prefix)
    t.assert_equals(cg.module._params.pending_size, options.pending_size)
    t.assert_equals(cg.module._params.flush_timeout, options.flush_timeout)
    t.assert_equals(cg.module._params.flusher_queue_size, options.flusher_queue_size)
end

group.test_setup_client_options_error = function(cg)
    cg.module:_setup_server_pool({'nats://localhost:4223'})
    local ok, err = pcall(cg.module._setup_client_options, cg.module, 'string')
    t.assert_not(ok)
    t.assert_equals(err.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(err.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(err.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_setup_client_options_randomize_server_pool = function(cg)
    local serv_pool = {'nats://localhost:4223', 'nats://localhost:4224', 'nats://localhost:4225',
                       'nats://localhost:4226', 'nats://localhost:4227', 'nats://localhost:4228',
                       'nats://localhost:4229', 'nats://localhost:4230', 'nats://localhost:4231',
                       'nats://localhost:4232' }
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options({ dont_randomize = false })
    local serv_pool_sorted = {}
    for _, serv in pairs(cg.module._server_pool) do
        table.insert(serv_pool_sorted, uri.format(serv.uri))
    end
    t.assert_not_equals(serv_pool, serv_pool_sorted)
end

group.test_setup_client_options_not_randomize_server_pool = function(cg)
    local serv_pool = {'nats://localhost:4223', 'nats://localhost:4224', 'nats://localhost:4225',
                       'nats://localhost:4226', 'nats://localhost:4227', 'nats://localhost:4228',
                       'nats://localhost:4229', 'nats://localhost:4230', 'nats://localhost:4231',
                       'nats://localhost:4232' }
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options({ dont_randomize = true })
    local serv_pool_sorted = {}
    for _, serv in pairs(cg.module._server_pool) do
        table.insert(serv_pool_sorted, uri.format(serv.uri))
    end
    t.assert_equals(serv_pool, serv_pool_sorted)
end

group.test_select_next_server_one_server = function(cg)
    local serv_pool = {'nats://127.0.0.1:4223', 'nats://127.0.0.1:4224', 'nats://127.0.0.1:4225'}
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options()
    local conn_count = 0
    local function connect_cb(_, _, _, _, _)
        conn_count = conn_count + 1
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4224, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    cg.module:_select_next_server()
    fiber.yield()
    t.assert_equals(conn_count, 1)
    t.assert_equals(cg.module._current_server.uri.service, '4224')
    cg.module._transport:close()
end

group.test_select_next_server_three_server = function(cg)
    local serv_pool = {'nats://127.0.0.1:4223', 'nats://127.0.0.1:4224', 'nats://127.0.0.1:4225'}
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options()
    local conn_count = 0
    local function connect_cb(_, _, _, _, _)
        conn_count = conn_count + 1
    end
    local server1 = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    server1:start()
    fiber.yield()
    local server2 = MockNatsServer.new('127.0.0.1', 4224, cg.server_info, connect_cb)
    server2:start()
    fiber.yield()
    local server3 = MockNatsServer.new('127.0.0.1', 4225, cg.server_info, connect_cb)
    server3:start()
    fiber.yield()
    cg.module:_select_next_server()
    fiber.yield()
    t.assert_equals(conn_count, 1)
    if cg.module._current_server.uri.service == '4223' then
        server1:stop()
    elseif cg.module._current_server.uri.service == '4224' then
        server2:stop()
    elseif cg.module._current_server.uri.service == '4225' then
        server3:stop()
    end
    cg.module:_select_next_server()
    fiber.yield()
    t.assert_equals(conn_count, 2)
    if cg.module._current_server.uri.service == '4223' then
        server1:stop()
    elseif cg.module._current_server.uri.service == '4224' then
        server2:stop()
    elseif cg.module._current_server.uri.service == '4225' then
        server3:stop()
    end
    cg.module:_select_next_server()
    fiber.yield()
    t.assert_equals(conn_count, 3)
    if cg.module._current_server.uri.service == '4223' then
        server1:stop()
    elseif cg.module._current_server.uri.service == '4224' then
        server2:stop()
    elseif cg.module._current_server.uri.service == '4225' then
        server3:stop()
    end
    cg.module._transport:close()
end

group.test_select_next_server_no_servers = function(cg)
    local serv_pool = {'nats://127.0.0.1:4223', 'nats://127.0.0.1:4224', 'nats://127.0.0.1:4225'}
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options({ connect_timeout = 0.5, max_reconnect_attempts = 1 })
    t.assert_error_covers(NatsErrorEnum.no_servers, cg.module._select_next_server, cg.module)
end

group.test_process_connect_init_default = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    t.assert_equals(nc._current_server.info.server_id, cg.server_info.server_id)
    t.assert_equals(nc._current_server.info.server_name, cg.server_info.server_name)
    t.assert_equals(nc._current_server.info.version:tostring(), cg.server_info.version)
    t.assert_equals(nc._current_server.info.proto, cg.server_info.proto)
    t.assert_equals(nc._current_server.info.proto, conn.protocol)
    t.assert_equals(nc._current_server.info.git_commit, cg.server_info.git_commit)
    t.assert_equals('go' .. nc._current_server.info.go:tostring(), cg.server_info.go)
    t.assert_equals(nc._current_server.info.headers, cg.server_info.headers)
    t.assert_equals(nc._current_server.info.headers, conn.headers)
    t.assert_equals(nc._current_server.info.max_payload, cg.server_info.max_payload)
    t.assert_equals(nc._current_server.info.client_id, cg.server_info.client_id)
    t.assert_equals(nc._current_server.info.xkey, cg.server_info.xkey)
    t.assert_equals(nc._current_server.info.host, '127.0.0.1')
    t.assert_equals(nc._current_server.info.port, 4223)
    t.assert_equals(nc._current_server.info.client_ip, '127.0.0.1')
    nc:close()
end

group.test_process_connect_init_read_info_error = function(cg)
    local function connect_cb(sock, _, _, _, _)
        sock:close()
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local ok, err = pcall(cg.module.new, 'nats://127.0.0.1:4223', { allow_reconnect = false })
    t.assert_not(ok)
    t.assert_equals(NatsErrorEnum.tcp_transport.code, err.code)
    t.assert_equals(NatsErrorEnum.tcp_transport.type, err.type)
    t.assert_str_contains(err.message, NatsErrorEnum.tcp_transport.message)
end

group.test_process_connect_init_parse_info_error = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.msg .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    t.assert_error_covers(NatsErrorEnum.unexpected_eof, cg.module.new, 'nats://127.0.0.1:4223', { allow_reconnect = false })
end

group.test_process_connect_init_not_info_error = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    t.assert_error_covers(NatsErrorEnum.connection_not_info_msg, cg.module.new, 'nats://127.0.0.1:4223', { allow_reconnect = false })
end

group.test_process_connect_init_write_con_error = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        sock:close()
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local ok, err = pcall(cg.module.new, 'nats://127.0.0.1:4223', { allow_reconnect = false })
    t.assert_not(ok)
    t.assert_equals(NatsErrorEnum.tcp_transport.code, err.code)
    t.assert_equals(NatsErrorEnum.tcp_transport.type, err.type)
    t.assert_str_contains(err.message, NatsErrorEnum.tcp_transport.message)
end

group.test_process_connect_init_ping_first = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    t.assert_equals(nc._current_server.info.server_id, cg.server_info.server_id)
    t.assert_equals(nc._current_server.info.server_name, cg.server_info.server_name)
    t.assert_equals(nc._current_server.info.version:tostring(), cg.server_info.version)
    t.assert_equals(nc._current_server.info.proto, cg.server_info.proto)
    t.assert_equals(nc._current_server.info.proto, conn.protocol)
    t.assert_equals(nc._current_server.info.git_commit, cg.server_info.git_commit)
    t.assert_equals('go' .. nc._current_server.info.go:tostring(), cg.server_info.go)
    t.assert_equals(nc._current_server.info.headers, cg.server_info.headers)
    t.assert_equals(nc._current_server.info.headers, conn.headers)
    t.assert_equals(nc._current_server.info.max_payload, cg.server_info.max_payload)
    t.assert_equals(nc._current_server.info.client_id, cg.server_info.client_id)
    t.assert_equals(nc._current_server.info.xkey, cg.server_info.xkey)
    t.assert_equals(nc._current_server.info.host, '127.0.0.1')
    t.assert_equals(nc._current_server.info.port, 4223)
    t.assert_equals(nc._current_server.info.client_ip, '127.0.0.1')
    nc:close()
end

group.test_process_connect_init_verbose = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223', { verbose = true })
    fiber.yield()
    t.assert_equals(nc._current_server.info.server_id, cg.server_info.server_id)
    t.assert_equals(nc._current_server.info.server_name, cg.server_info.server_name)
    t.assert_equals(nc._current_server.info.version:tostring(), cg.server_info.version)
    t.assert_equals(nc._current_server.info.proto, cg.server_info.proto)
    t.assert_equals(nc._current_server.info.proto, conn.protocol)
    t.assert_equals(nc._current_server.info.git_commit, cg.server_info.git_commit)
    t.assert_equals('go' .. nc._current_server.info.go:tostring(), cg.server_info.go)
    t.assert_equals(nc._current_server.info.headers, cg.server_info.headers)
    t.assert_equals(nc._current_server.info.headers, conn.headers)
    t.assert_equals(nc._current_server.info.max_payload, cg.server_info.max_payload)
    t.assert_equals(nc._current_server.info.client_id, cg.server_info.client_id)
    t.assert_equals(nc._current_server.info.xkey, cg.server_info.xkey)
    t.assert_equals(nc._current_server.info.host, '127.0.0.1')
    t.assert_equals(nc._current_server.info.port, 4223)
    t.assert_equals(nc._current_server.info.client_ip, '127.0.0.1')
    nc:close()
end

group.test_process_connect_init_server_returned_error = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.err .. " 'Parser Error'" .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local ok, err = pcall(cg.module.new, 'nats://127.0.0.1:4223', { allow_reconnect = false })
    t.assert_not(ok)
    t.assert_equals(NatsErrorEnum.parser_err.code, err.code)
    t.assert_equals(NatsErrorEnum.parser_err.type, err.type)
    t.assert_str_contains(err.message, NatsErrorEnum.parser_err.message)
end

group.test_ping = function(cg)
    local conn
    local ping_count = 5
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        while ping_count > 0 do
            ping = sock:read(NatsProtocolConstants.delimiter)
            t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
            sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            ping_count = ping_count - 1
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223', { ping_interval = 1 })
    fiber.yield()
    t.assert_equals(nc._current_server.info.server_id, cg.server_info.server_id)
    t.assert_equals(nc._current_server.info.server_name, cg.server_info.server_name)
    t.assert_equals(nc._current_server.info.version:tostring(), cg.server_info.version)
    t.assert_equals(nc._current_server.info.proto, cg.server_info.proto)
    t.assert_equals(nc._current_server.info.proto, conn.protocol)
    t.assert_equals(nc._current_server.info.git_commit, cg.server_info.git_commit)
    t.assert_equals('go' .. nc._current_server.info.go:tostring(), cg.server_info.go)
    t.assert_equals(nc._current_server.info.headers, cg.server_info.headers)
    t.assert_equals(nc._current_server.info.headers, conn.headers)
    t.assert_equals(nc._current_server.info.max_payload, cg.server_info.max_payload)
    t.assert_equals(nc._current_server.info.client_id, cg.server_info.client_id)
    t.assert_equals(nc._current_server.info.xkey, cg.server_info.xkey)
    t.assert_equals(nc._current_server.info.host, '127.0.0.1')
    t.assert_equals(nc._current_server.info.port, 4223)
    t.assert_equals(nc._current_server.info.client_ip, '127.0.0.1')
    local start = fiber.clock()
    while ping_count > 0 and fiber.clock() - start < 10 do
        fiber.yield()
    end
    nc:close()
    t.assert_equals(0, ping_count)
end

group.test_pong = function(cg)
    local conn
    local pong_count = 5
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        while pong_count > 0 do
            sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
            pong = sock:read(NatsProtocolConstants.delimiter)
            t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            pong_count = pong_count - 1
            fiber.sleep(0.5)
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    t.assert_equals(nc._current_server.info.server_id, cg.server_info.server_id)
    t.assert_equals(nc._current_server.info.server_name, cg.server_info.server_name)
    t.assert_equals(nc._current_server.info.version:tostring(), cg.server_info.version)
    t.assert_equals(nc._current_server.info.proto, cg.server_info.proto)
    t.assert_equals(nc._current_server.info.proto, conn.protocol)
    t.assert_equals(nc._current_server.info.git_commit, cg.server_info.git_commit)
    t.assert_equals('go' .. nc._current_server.info.go:tostring(), cg.server_info.go)
    t.assert_equals(nc._current_server.info.headers, cg.server_info.headers)
    t.assert_equals(nc._current_server.info.headers, conn.headers)
    t.assert_equals(nc._current_server.info.max_payload, cg.server_info.max_payload)
    t.assert_equals(nc._current_server.info.client_id, cg.server_info.client_id)
    t.assert_equals(nc._current_server.info.xkey, cg.server_info.xkey)
    t.assert_equals(nc._current_server.info.host, '127.0.0.1')
    t.assert_equals(nc._current_server.info.port, 4223)
    t.assert_equals(nc._current_server.info.client_ip, '127.0.0.1')
    local start = fiber.clock()
    while pong_count > 0 and fiber.clock() - start < 10 do
        fiber.yield()
    end
    nc:close()
    t.assert_equals(0, pong_count)
end

group.test_publish_without_reply_without_headers = function(cg)
    local conn, msg
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg = sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:publish('foo', 'bar')
    fiber.yield()
    t.assert_equals(nc.stats.out_msgs, 1)
    t.assert_equals(nc.stats.out_bytes, 3)
    nc:close()
    t.assert_equals(msg, 'PUB foo 3\r\nbar\r\n')
end

group.test_publish_without_reply_without_headers_max_payload = function(cg)
    local conn, msg
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg = sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
    end
    local server_info = table.deepcopy(cg.server_info)
    server_info.max_payload = 10
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    t.assert_error_covers(NatsErrorEnum.max_payload, nc.publish, nc, 'foo', 'bar baz 123')
    nc:close()
end

group.test_publish_with_reply_without_headers = function(cg)
    local conn, msg
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg = sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:publish('foo', 'bar', 'baz')
    fiber.yield()
    t.assert_equals(nc.stats.out_msgs, 1)
    t.assert_equals(nc.stats.out_bytes, 3)
    nc:close()
    t.assert_equals(msg, 'PUB foo baz 3\r\nbar\r\n')
end

group.test_publish_without_reply_with_headers = function(cg)
    local conn, msg
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg = sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:publish('foo', 'bar', nil, {foo = 'bar'})
    fiber.yield()
    t.assert_equals(nc.stats.out_msgs, 1)
    t.assert_equals(nc.stats.out_bytes, 3)
    nc:close()
    t.assert_equals(msg, 'HPUB foo 22 25\r\nNATS/1.0\r\nfoo: bar\r\n\r\nbar\r\n')
end

group.test_publish_with_reply_with_headers = function(cg)
    local conn, msg
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg = sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
        msg = msg .. sock:read(NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:publish('foo', 'bar', 'baz', {foo = 'bar'})
    fiber.yield()
    t.assert_equals(nc.stats.out_msgs, 1)
    t.assert_equals(nc.stats.out_bytes, 3)
    nc:close()
    t.assert_equals(msg, 'HPUB foo baz 22 25\r\nNATS/1.0\r\nfoo: bar\r\n\r\nbar\r\n')
end

group.test_subscribe_without_queue = function(cg)
    local conn, msg_sub, msg_unsub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:subscribe('foo')
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    nc:close()
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    t.assert_equals(msg_sub, 'SUB foo 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1\r\n')
end

group.test_subscribe_with_queue = function(cg)
    local conn, msg_sub, msg_unsub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:subscribe('foo', 'bar')
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    nc:close()
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    t.assert_equals(msg_sub, 'SUB foo bar 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1\r\n')
end

group.test_unsubscribe_without_limit = function(cg)
    local conn, msg_sub, msg_unsub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    local sub = nc:subscribe('foo', 'bar')
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    sub:unsubscribe()
    fiber.sleep(0.5)
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    nc:close()
    t.assert_equals(msg_sub, 'SUB foo bar 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1 0\r\n')
end

group.test_unsubscribe_with_limit = function(cg)
    local conn, msg_sub, msg_unsub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    local sub = nc:subscribe('foo', 'bar')
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    sub:unsubscribe(10)
    fiber.sleep(0.5)
    t.assert_equals(msg_unsub, 'UNSUB 1 10\r\n')
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    nc:close()
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    t.assert_equals(msg_sub, 'SUB foo bar 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1\r\n')
end

group.test_new_inbox = function(cg)
    local conn
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    for _ = 1, 100, 1 do
        t.assert_not_equals(nc:new_inbox(), nc:new_inbox())
    end
    t.assert_str_contains(nc:new_inbox(), nc._params.inbox_prefix .. '.')
    nc:close()
end

group.test_subscribe_next_msg = function(cg)
    local conn, msg_sub, msg_unsub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            elseif string.startswith(msg, NatsProtocolConstants.pub) then
                local slices  = {}
                for slice in msg:gmatch('[^%s]+') do
                    table.insert(slices, slice)
                end
                local send_msg = 'MSG foo 1 ' .. slices[3] .. NatsProtocolConstants.delimiter .. sock:read(NatsProtocolConstants.delimiter)
                sock:write(send_msg)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    local sub = nc:subscribe('foo')
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    nc:publish('foo', 'bar')
    fiber.yield()
    local msg = sub:next_msg(1)
    fiber.yield()
    nc:close()
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    t.assert_equals(msg_sub, 'SUB foo 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1\r\n')
    t.assert_equals(msg.payload, 'bar')
    t.assert_equals(msg.subject, 'foo')
end

group.test_subscribe_callback = function(cg)
    local conn, msg_sub, msg_unsub
    local function msg_handler(msg)
        t.assert_equals(msg.payload, 'bar')
        t.assert_equals(msg.subject, 'foo')
    end
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                msg_unsub = msg
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            elseif string.startswith(msg, NatsProtocolConstants.pub) then
                local slices  = {}
                for slice in msg:gmatch('[^%s]+') do
                    table.insert(slices, slice)
                end
                local send_msg = 'MSG foo 1 ' .. slices[3] .. NatsProtocolConstants.delimiter .. sock:read(NatsProtocolConstants.delimiter)
                sock:write(send_msg)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    nc:subscribe('foo', nil, msg_handler)
    fiber.yield()
    local sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 1)
    nc:publish('foo', 'bar')
    fiber.yield()
    nc:close()
    sub_count = 0
    for _, _ in pairs(nc._subs) do
        sub_count = sub_count + 1
    end
    t.assert_equals(sub_count, 0)
    t.assert_equals(msg_sub, 'SUB foo 1\r\n')
    t.assert_equals(msg_unsub, 'UNSUB 1\r\n')
end

group.test_request = function(cg)
    local conn, msg_sub
    local function connect_cb(sock, from, host, port, server_info)
        server_info.host = host
        server_info.port = port
        server_info.client_ip = from.host
        sock:write(NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        local pong = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(pong, NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.info .. ' ' .. json.encode(server_info) .. NatsProtocolConstants.delimiter)
        local conn_info = sock:read(NatsProtocolConstants.delimiter)
        conn = json.decode(string.lstrip(conn_info, NatsProtocolConstants.connect .. ' '))
        if conn.verbose then
            sock:write(NatsProtocolConstants.ok .. NatsProtocolConstants.delimiter)
        end
        local ping = sock:read(NatsProtocolConstants.delimiter)
        t.assert_equals(ping, NatsProtocolConstants.ping .. NatsProtocolConstants.delimiter)
        sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
        msg_sub = sock:read(NatsProtocolConstants.delimiter)
        while true do
            local msg = sock:read(NatsProtocolConstants.delimiter)
            if msg == nil or msg == '' then
                break
            end
            if string.startswith(msg, NatsProtocolConstants.unsub) then
                print('UNSUB')
            elseif string.startswith(msg, NatsProtocolConstants.ping) then
                sock:write(NatsProtocolConstants.pong .. NatsProtocolConstants.delimiter)
            elseif string.startswith(msg, NatsProtocolConstants.pub) then
                local slices  = {}
                for slice in msg:gmatch('[^%s]+') do
                    table.insert(slices, slice)
                end
                local send_msg = 'MSG ' .. slices[3] .. ' 1 ' .. slices[4] .. NatsProtocolConstants.delimiter .. sock:read(NatsProtocolConstants.delimiter)
                print(send_msg)
                sock:write(send_msg)
            end
        end
    end
    cg.mock_nats_server = MockNatsServer.new('127.0.0.1', 4223, cg.server_info, connect_cb)
    cg.mock_nats_server:start()
    fiber.yield()
    local nc = cg.module.new('nats://127.0.0.1:4223')
    fiber.yield()
    local msg = nc:request('foo', 'bar')
    fiber.yield()
    nc:close()
    t.assert_equals(msg.payload, 'bar')
    t.assert_str_contains(msg_sub, 'SUB')
end