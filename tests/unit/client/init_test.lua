local t = require('luatest')
local uri = require('uri')

local helper = require('tests.helpers.unit')


local NatsClient = require('nats').NatsClient
local NatsErrorEnum = require('nats.utils.errors')
local versions = require('nats.version')
local Version = require('nats.utils.version')


local group =  t.group('module-client-init')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.before_each(
        function(cg)
            cg.module = table.deepcopy(NatsClient)
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
    local serv_pool = {'nats://localhost:4223', 'nats://localhost:4224', 'nats://localhost:4225'}
    cg.module:_setup_server_pool(serv_pool)
    cg.module:_setup_client_options({ dont_randomize = false })
    local serv_pool_sorted = {}
    for _, serv in pairs(cg.module._server_pool) do
        table.insert(serv_pool_sorted, uri.format(serv.uri))
    end
    t.assert_not_equals(serv_pool, serv_pool_sorted)
end