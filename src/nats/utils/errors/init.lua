local default_con_type = 'NATS connector'
local default_serv_type = 'NATS server'


---@class NatsErrorEnum: table
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
---@field connection_not_info_msg Error
---@field unsubscribe_queue_not_empty Error
---@field unexpected Error
---@field unk_protocol_err Error
---@field con_route_port Error
---@field authorization_violation Error
---@field authorization_timeout Error
---@field invalid_client_protocol Error
---@field max_control_line Error
---@field parser_err Error
---@field tls_required Error
---@field stale_connection_serv Error
---@field max_connections Error
---@field slow_consumer_serv Error
---@field max_payload_serv Error
---@field invalid_subject Error
---@field permission_read_subject Error
---@field permission_write_subject Error
---@field unexpected_serv Error
local NatsErrorEnum = {
    invalid_connect_params = { message = 'Invalid connection parameters', type = default_con_type, code = 1 },
    mix_connect_params = {
            message = 'Mixing of websocket and non websocket URLs is not allowed',
            type = default_con_type,
            code = 2
        },
    timeout = { message = 'Timeout', type = default_con_type, code = 3 },
    no_responders = { message = 'No responders available for request', type = default_con_type, code = 4 },
    stale_connection = { message = 'Stale connection', type = default_con_type, code = 5 },
    outbound_buffer_limit = { message = 'Outbound buffer limit exceeded', type = default_con_type, code = 6 },
    unexpected_eof = { message = 'Unexpected EOF', type = default_con_type, code = 7 },
    flush_timeout = { message = 'Flush timeout', type = default_con_type, code = 8 },
    connection_closed = { message = 'Connection closed', type = default_con_type, code = 9 },
    secure_conn_required = { message = 'Secure connection required', type = default_con_type, code = 10 },
    secure_conn_wanted = { message = 'Secure connection not available', type = default_con_type, code = 11 },
    secure_conn_failed ={ message = 'Secure connection failed', type = default_con_type, code = 12 },
    bad_subscription = { message = 'Invalid subscription', type = default_con_type, code = 13 },
    bad_subject = { message = 'Invalid subject', type = default_con_type, code = 14 },
    slow_consumer = { message = 'Slow consumer', type = default_con_type, code = 15 },
    bad_timeout = { message = 'Timeout invalid', type = default_con_type, code = 16 },
    authorization = { message = 'Authorization failed', type = default_con_type, code = 17 },
    no_servers = { message = 'No servers available for connection', type = default_con_type, code = 18 },
    json_parse ={ message = 'Connect message, json parse error', type = default_con_type, code = 19 },
    max_payload = { message = 'Maximum payload exceeded', type = default_con_type, code = 20 },
    drain_timeout = { message = 'Draining connection timed out', type = default_con_type, code = 21 },
    connection_draining = { message = 'Connection draining', type = default_con_type, code = 22 },
    connection_reconnecting = { message = 'Connection reconnecting', type = default_con_type, code = 23 },
    invalid_user_credentials = { message = 'Invalid user credentials', type = default_con_type, code = 24 },
    invalid_callback_type = { message = 'Callbacks must be functions', type = default_con_type, code = 25 },
    protocol = { message = 'Protocol error', type = default_con_type, code = 26 },
    not_js_message = { message = 'Not a JetStream message', type = default_con_type, code = 27 },
    msg_already_ackd = { message = 'Message was already acknowledged', type = default_con_type, code = 28 },
    tcp_transport = { message = 'TCP transport error: ', type = default_con_type, code = 29 },
    connection_not_info_msg = { message = 'Empty response from server when expecting INFO message',
                                type    = default_con_type, code = 30 },
    unsubscribe_queue_not_empty = { message = 'Pending queue not empty',
                                    type    = default_con_type, code = 31 },
    unexpected = { message = 'Unexpected error', type = default_con_type, code = 50 },
    unk_protocol_err = { message = 'Unknown protocol error', type = default_serv_type, code = 51 },
    con_route_port = { message = 'Client attempted to connect to a route port instead of the client port',
                         type = default_serv_type, code = 52 },
    authorization_violation = {
        message = 'Client failed to authenticate to the server with credentials specified in the CONNECT message',
        type = default_serv_type, code = 53
    },
    authorization_timeout = {
        message = 'Client took too long to authenticate to the server after establishing a connection',
        type = default_serv_type, code = 54
    },
    invalid_client_protocol = { message = 'Client specified an invalid protocol version in the CONNECT message',
                         type = default_serv_type, code = 55 },
    max_control_line = {
        message = 'Message destination subject and reply subject length exceeded the maximum control line value specified by the max_control_line server option',
        type = default_serv_type,
        code = 56
    },
    parser_err = { message = 'Cannot parse the protocol message sent by the client',
                         type = default_serv_type, code = 57 },
    tls_required = { message = 'The server requires TLS and the client does not have TLS enabled',
                         type = default_serv_type, code = 58 },
    stale_connection_serv = {
        message = 'The server has not received a message from the client, including a PONG in too long.',
        type = default_serv_type,
        code = 59
    },
    max_connections = {
        message = 'This error is sent by the server when creating a new connection and the server has exceeded the maximum number of connections specified by the max_connections server option',
        type = default_serv_type,
        code = 60
    },
    slow_consumer_serv = { message = 'The server pending data size for the connection has reached the maximum size',
                         type = default_serv_type, code = 61 },
    max_payload_serv = {
        message = 'Client attempted to publish a message with a payload size that exceeds the max_payload size configured on the server',
        type = default_serv_type,
        code = 62
    },
    invalid_subject = { message = 'Client sent a malformed subject',
                           type = default_serv_type, code = 63 },
    permission_read_subject = {
        message = 'The user specified in the CONNECT message does not have permission to subscribe to the subject',
        type = default_serv_type,
        code = 64
    },
    permission_write_subject = {
        message = 'The user specified in the CONNECT message does not have permissions to publish to the subject',
        type = default_serv_type,
        code = 65
    },
    unexpected_serv = { message = 'Server return unexpected error', type = default_serv_type, code = 80 }
}


return NatsErrorEnum
