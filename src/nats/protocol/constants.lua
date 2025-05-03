---@class NatsProtocolConstants: enum
---@field public delimiter string @message separator
---@field public info string @information message
---@field public msg string @message
---@field public hmsg string @message with headers
---@field public ping string @ping message\command
---@field public pong string @pong message\command
---@field public ok string @message ok
---@field public err string @error message
---@field public headers string @header format version
---@field public connect string @connection command
---@field public pub string @post command
---@field public hpub string @command to publish a message with headers
---@field public sub string @subscribe to subject command
---@field public unsub string @unsubscribe command from subject
local NatsProtocolConstants = {
    delimiter = '\r\n',
    info = 'INFO',
    msg = 'MSG',
    hmsg = 'HMSG',
    ping = 'PING',
    pong = 'PONG',
    ok = '+OK',
    err = '-ERR',
    headers = 'NATS/1.0',
    connect = 'CONNECT',
    pub = 'PUB',
    hpub = 'HPUB',
    sub = 'SUB',
    unsub = 'UNSUB'
}

return NatsProtocolConstants
