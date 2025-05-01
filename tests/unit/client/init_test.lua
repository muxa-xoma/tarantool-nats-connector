local t = require('luatest')

local helper = require('tests.helpers.unit')


local NatsClient = require('nats').NatsClient
local NatsErrorEnum = require('nats.utils.errors')


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

