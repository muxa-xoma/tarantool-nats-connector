local t = require('luatest')

local helper = require('tests.helpers.unit')

local NatsErrorEnum = require('nats.utils.errors')
local NatsClientOptions = require('nats.client.options')


local group =  t.group('module-client-options')

group.before_all(
        function(cg)
            cg.helper = helper
        end
)

group.test_new_options_nil = function()
    ---@type Result
    local result = NatsClientOptions.new(nil)
    t.assert(result.success)
    ---@type NatsClientOptions
    local options = result.data
    t.assert_type(options, 'table')
    t.assert_type(options.error_cb, 'function')
    t.assert_equals(options.disconnected_cb, nil)
    t.assert_equals(options.closed_cb, nil)
    t.assert_equals(options.discovered_server_cb, nil)
    t.assert_equals(options.reconnected_cb, nil)
    t.assert_equals(options.name, nil)
    t.assert_equals(options.allow_reconnect, true)
    t.assert_equals(options.verbose, false)
    t.assert_equals(options.pedantic, false)
    t.assert_equals(options.connect_timeout, 2)
    t.assert_equals(options.reconnect_time_wait, 2)
    t.assert_equals(options.max_reconnect_attempts, 60)
    t.assert_equals(options.ping_interval, 120)
    t.assert_equals(options.max_outstanding_pings, 2)
    t.assert_equals(options.dont_randomize, false)
    t.assert_equals(options.no_echo, false)
    t.assert_equals(options.user, nil)
    t.assert_equals(options.password, nil)
    t.assert_equals(options.drain_timeout, 30)
    t.assert_equals(options.inbox_prefix, '_INBOX')
    t.assert_equals(options.pending_size, 2 * 1024 * 1024)
    t.assert_equals(options.flush_timeout, 10)
    t.assert_equals(options.flusher_queue_size, 1024)
end

group.test_new_empty_table = function()
    ---@type Result
    local result = NatsClientOptions.new({})
    t.assert(result.success)
    ---@type NatsClientOptions
    local options = result.data
    t.assert_type(options, 'table')
    t.assert_type(options.error_cb, 'function')
    t.assert_equals(options.disconnected_cb, nil)
    t.assert_equals(options.closed_cb, nil)
    t.assert_equals(options.discovered_server_cb, nil)
    t.assert_equals(options.reconnected_cb, nil)
    t.assert_equals(options.name, nil)
    t.assert_equals(options.allow_reconnect, true)
    t.assert_equals(options.verbose, false)
    t.assert_equals(options.pedantic, false)
    t.assert_equals(options.connect_timeout, 2)
    t.assert_equals(options.reconnect_time_wait, 2)
    t.assert_equals(options.max_reconnect_attempts, 60)
    t.assert_equals(options.ping_interval, 120)
    t.assert_equals(options.max_outstanding_pings, 2)
    t.assert_equals(options.dont_randomize, false)
    t.assert_equals(options.no_echo, false)
    t.assert_equals(options.user, nil)
    t.assert_equals(options.password, nil)
    t.assert_equals(options.drain_timeout, 30)
    t.assert_equals(options.inbox_prefix, '_INBOX')
    t.assert_equals(options.pending_size, 2 * 1024 * 1024)
    t.assert_equals(options.flush_timeout, 10)
    t.assert_equals(options.flusher_queue_size, 1024)
end

group.test_new_not_table = function()
    ---@type Result
    local result = NatsClientOptions.new('string')
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_error_cb_not_function = function()
    ---@type Result
    local result = NatsClientOptions.new({error_cb = false})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_disconnected_cb_not_function = function()
    ---@type Result
    local result = NatsClientOptions.new({disconnected_cb = true})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_closed_cb_not_function = function()
    ---@type Result
    local result = NatsClientOptions.new({closed_cb = 15})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_discovered_server_cb_not_function = function()
    ---@type Result
    local result = NatsClientOptions.new({discovered_server_cb = { false }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_reconnected_cb_not_function = function()
    ---@type Result
    local result = NatsClientOptions.new({reconnected_cb = 'string'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_name_not_string = function()
    ---@type Result
    local result = NatsClientOptions.new({name = true})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_user_not_string = function()
    ---@type Result
    local result = NatsClientOptions.new({user = false})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_password_not_string = function()
    ---@type Result
    local result = NatsClientOptions.new({password = 159})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_inbox_prefix_not_string = function()
    ---@type Result
    local result = NatsClientOptions.new({inbox_prefix = { true }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_no_echo_not_boolean = function()
    ---@type Result
    local result = NatsClientOptions.new({no_echo = { true }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_pedantic_not_boolean = function()
    ---@type Result
    local result = NatsClientOptions.new({pedantic = 'string'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_verbose_not_boolean = function()
    ---@type Result
    local result = NatsClientOptions.new({verbose = 169})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_allow_reconnect_not_boolean = function()
    ---@type Result
    local result = NatsClientOptions.new({allow_reconnect = 95.5})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_dont_randomize_not_boolean = function()
    ---@type Result
    local result = NatsClientOptions.new({dont_randomize = { dont_randomize = true }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_connect_timeout_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({connect_timeout = { connect_timeout = 15 }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_reconnect_time_wait_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({reconnect_time_wait = { 15 }})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_max_reconnect_attempts_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({max_reconnect_attempts = true})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_ping_interval_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({ping_interval = false})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_max_outstanding_pings_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({max_outstanding_pings = '65'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_drain_timeout_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({drain_timeout = ''})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_pending_size_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({pending_size = 'true'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_flush_timeout_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({flush_timeout = 'false'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_flusher_queue_size_not_number = function()
    ---@type Result
    local result = NatsClientOptions.new({flusher_queue_size = 'flusher_queue_size'})
    t.assert_not(result.success)
    ---@type Error
    local options = result.error
    t.assert_equals(options.code, NatsErrorEnum.invalid_connect_params.code)
    t.assert_equals(options.type, NatsErrorEnum.invalid_connect_params.type)
    t.assert_str_contains(options.message, NatsErrorEnum.invalid_connect_params.message)
end

group.test_new_full_table = function()
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
    local result = NatsClientOptions.new(options)
    t.assert(result.success)
    ---@type NatsClientOptions
    local options_result = result.data
    t.assert_type(options_result.error_cb, 'function')
    t.assert_type(options_result.disconnected_cb, 'function')
    t.assert_type(options_result.closed_cb, 'function')
    t.assert_type(options_result.discovered_server_cb, 'function')
    t.assert_type(options_result.reconnected_cb, 'function')
    t.assert_equals(options_result.error_cb, options.error_cb)
    t.assert_equals(options_result.disconnected_cb, options.disconnected_cb)
    t.assert_equals(options_result.closed_cb, options.closed_cb)
    t.assert_equals(options_result.discovered_server_cb, options.discovered_server_cb)
    t.assert_equals(options_result.reconnected_cb, options.reconnected_cb)
    t.assert_equals(options_result.verbose, options.verbose)
    t.assert_equals(options_result.pedantic, options.pedantic)
    t.assert_equals(options_result.no_echo, options.no_echo)
    t.assert_equals(options_result.name, options.name)
    t.assert_equals(options_result.user, options.user)
    t.assert_equals(options_result.password, options.password)
    t.assert_equals(options_result.allow_reconnect, options.allow_reconnect)
    t.assert_equals(options_result.connect_timeout, options.connect_timeout)
    t.assert_equals(options_result.reconnect_time_wait, options.reconnect_time_wait)
    t.assert_equals(options_result.max_reconnect_attempts, options.max_reconnect_attempts)
    t.assert_equals(options_result.ping_interval, options.ping_interval)
    t.assert_equals(options_result.max_outstanding_pings, options.max_outstanding_pings)
    t.assert_equals(options_result.drain_timeout, options.drain_timeout)
    t.assert_equals(options_result.inbox_prefix, options.inbox_prefix)
    t.assert_equals(options_result.pending_size, options.pending_size)
    t.assert_equals(options_result.flush_timeout, options.flush_timeout)
    t.assert_equals(options_result.flusher_queue_size, options.flusher_queue_size)
    t.assert_equals(options_result.dont_randomize, options.dont_randomize)
end

