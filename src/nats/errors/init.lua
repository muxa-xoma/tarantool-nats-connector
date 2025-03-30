local default_type = 'NATS connector'


---@class NatsError: table
---@alias Error { code: number, message: string, type: string }
---@field invalid_connect_params Error
---@field mix_connect_params Error
---@field timeout Error
---@field no_responders Error
---@field stale_connection Error
---@field outbound_buffer_limit Error
---@field unexpected_eof Error
---@field flush_timeout Error
---@field connection_closed Error
---@field secure_conn_required Error
---@field secure_conn_wanted Error
---@field secure_conn_failed Error
---@field bad_subscription Error
---@field bad_subject Error
---@field slow_consumer Error
---@field bad_timeout Error
---@field authorization Error
---@field no_servers Error
---@field json_parse Error
---@field max_payload Error
---@field drain_timeout Error
---@field connection_draining Error
---@field connection_reconnecting Error
---@field invalid_user_credentials Error
---@field invalid_callback_type Error
---@field protocol Error
---@field not_js_message Error
---@field msg_already_ackd Error
---@field tcp_transport Error
---@field unexpected Error
local errors = {
    invalid_connect_params = { message = 'Invalid connection parameters', type = default_type, code = 1 },
    mix_connect_params = {
            message = 'Mixing of websocket and non websocket URLs is not allowed',
            type = default_type,
            code = 2
        },
    timeout = { message = 'Timeout', type = default_type, code = 3 },
    no_responders = { message = 'No responders available for request', type = default_type, code = 4 },
    stale_connection = { message = 'Stale connection', type = default_type, code = 5 },
    outbound_buffer_limit = { message = 'Outbound buffer limit exceeded', type = default_type, code = 6 },
    unexpected_eof = { message = 'Unexpected EOF', type = default_type, code = 7 },
    flush_timeout = { message = 'Flush timeout', type = default_type, code = 8 },
    connection_closed = { message = 'Connection closed', type = default_type, code = 9 },
    secure_conn_required = { message = 'Secure connection required', type = default_type, code = 10 },
    secure_conn_wanted = { message = 'Secure connection not available', type = default_type, code = 11 },
    secure_conn_failed ={ message = 'Secure connection failed', type = default_type, code = 12 },
    bad_subscription = { message = 'Invalid subscription', type = default_type, code = 13 },
    bad_subject = { message = 'Invalid subject', type = default_type, code = 14 },
    slow_consumer = { message = 'Slow consumer', type = default_type, code = 15 },
    bad_timeout = { message = 'Timeout invalid', type = default_type, code = 16 },
    authorization = { message = 'Authorization failed', type = default_type, code = 17 },
    no_servers = { message = 'No servers available for connection', type = default_type, code = 18 },
    json_parse ={ message = 'Connect message, json parse error', type = default_type, code = 19 },
    max_payload = { message = 'Maximum payload exceeded', type = default_type, code = 20 },
    drain_timeout = { message = 'Draining connection timed out', type = default_type, code = 21 },
    connection_draining = { message = 'Connection draining', type = default_type, code = 22 },
    connection_reconnecting = { message = 'Connection reconnecting', type = default_type, code = 23 },
    invalid_user_credentials = { message = 'Invalid user credentials', type = default_type, code = 24 },
    invalid_callback_type = { message = 'Callbacks must be functions', type = default_type, code = 25 },
    protocol = { message = 'Protocol error', type = default_type, code = 26 },
    not_js_message = { message = 'Not a JetStream message', type = default_type, code = 27 },
    msg_already_ackd = { message = 'Message was already acknowledged', type = default_type, code = 28 },
    tcp_transport = { message = 'TCP transport error: ', type = default_type, code = 29 },
    unexpected = { message = 'Unexpected error', type = default_type, code = 50 }
}


return errors
