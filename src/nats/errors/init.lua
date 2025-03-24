local default_type = 'NATS connector'
local default_code = 600

---@class errors: table
local errors = {
    invalid_connect_params = box.error.new(
        { reason = 'Invalid connection parameters', type = default_type, code = default_code + 1 }
    ),
    mix_connect_params = box.error.new(
        {
            reason = 'Mixing of websocket and non websocket URLs is not allowed',
            type = default_type,
            code = default_code + 2
        }
    ),
    timeout = box.error.new(
        { reason = 'Timeout', type = default_type, code = default_code + 3 }
    ),
    no_responders = box.error.new(
        { reason = 'No responders available for request', type = default_type, code = default_code + 4 }
    ),
    stale_connection = box.error.new(
        { reason = 'Stale connection', type = default_type, code = default_code + 5 }
    ),
    outbound_buffer_limit = box.error.new(
        { reason = 'Outbound buffer limit exceeded', type = default_type, code = default_code + 6 }
    ),
    unexpected_eof = box.error.new(
        { reason = 'Unexpected EOF', type = default_type, code = default_code + 7 }
    ),
    flush_timeout = box.error.new(
        { reason = 'Flush timeout', type = default_type, code = default_code + 8 }
    ),
    connection_closed = box.error.new(
        { reason = 'Connection closed', type = default_type, code = default_code + 9 }
    ),
    secure_conn_required = box.error.new(
        { reason = 'Secure connection required', type = default_type, code = default_code + 10 }
    ),
    secure_conn_wanted = box.error.new(
        { reason = 'Secure connection not available', type = default_type, code = default_code + 11 }
    ),
    secure_conn_failed = box.error.new(
        { reason = 'Secure connection failed', type = default_type, code = default_code + 12 }
    ),
    bad_subscription = box.error.new(
        { reason = 'Invalid subscription', type = default_type, code = default_code + 13 }
    ),
    bad_subject = box.error.new(
            { reason = 'Invalid subject', type = default_type, code = default_code + 14 }
    ),
    slow_consumer = box.error.new(
        { reason = 'Slow consumer', type = default_type, code = default_code + 15 }
    ),
    bad_timeout = box.error.new(
        { reason = 'Timeout invalid', type = default_type, code = default_code + 16 }
    ),
    authorization = box.error.new(
        { reason = 'Authorization failed', type = default_type, code = default_code + 17 }
    ),
    no_servers = box.error.new(
        { reason = 'No servers available for connection', type = default_type, code = default_code + 18 }
    ),
    json_parse = box.error.new(
        { reason = 'Connect message, json parse error', type = default_type, code = default_code + 19 }
    ),
    max_payload = box.error.new(
        { reason = 'Maximum payload exceeded', type = default_type, code = default_code + 20 }
    ),
    drain_timeout = box.error.new(
        { reason = 'Draining connection timed out', type = default_type, code = default_code + 21 }
    ),
    connection_draining = box.error.new(
        { reason = 'Connection draining', type = default_type, code = default_code + 22 }
    ),
    connection_reconnecting = box.error.new(
        { reason = 'Connection reconnecting', type = default_type, code = default_code + 23 }
    ),
    invalid_user_credentials = box.error.new(
        { reason = 'Invalid user credentials', type = default_type, code = default_code + 24 }
    ),
    invalid_callback_type = box.error.new(
        { reason = 'Callbacks must be functions', type = default_type, code = default_code + 25 }
    ),
    protocol = box.error.new(
        { reason = 'Protocol error', type = default_type, code = default_code + 26 }
    ),
    not_js_message = box.error.new(
        { reason = 'Not a JetStream message', type = default_type, code = default_code + 27 }
    ),
    msg_already_ackd = box.error.new(
        { reason = 'Message was already acknowledged', type = default_type, code = default_code + 28 }
    )
}


return errors
