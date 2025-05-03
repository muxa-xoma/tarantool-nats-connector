local json = require('json')
local uri = require('uri')

local Version = require('nats.utils.version')

---@class NatsServerInfo @class represents the server info response
---@alias URI { scheme: string, host: string, service: string, ipv4: string|nil }
---@field public server_id string @The unique identifier of the NATS server
---@field public server_name string @The name of the NATS server
---@field public version Version @The version of NATS
---@field public go Version @The version of golang the NATS server was built with
---@field public host string @The IP address used to start the NATS server
---@field public port number @The port number the NATS server is configured to listen on
---@field public headers boolean @Whether the server supports headers
---@field public max_payload number @Maximum payload size, in bytes, that the server will accept from the client
---@field public proto number @An integer indicating the protocol version of the server
---@field public client_id number|nil @The internal client identifier in the server
---@field public auth_required boolean|nil @If this is true, then the client should try to authenticate upon connect
---@field public tls_required boolean|nil @If this is true, then the client must perform the TLS/1.2 handshake.
---@field public tls_verify boolean|nil @If this is true, the client must provide a valid certificate during the TLS handshake
---@field public tls_available boolean|nil @If this is true, the client can provide a valid certificate during the TLS handshake
---@field public connect_urls URI[]|nil @List of server urls that a client can connect to
---@field public ws_connect_urls URI[]|nil @List of server urls that a websocket client can connect to
---@field public ldm boolean|nil @If the server supports Lame Duck Mode notifications, and the current server has transitioned to lame duck, ldm will be set to true
---@field public git_commit string|nil @The git hash at which the NATS server was built
---@field public jetstream boolean|nil @Whether the server supports JetStream
---@field public ip string|nil @The IP of the server
---@field public client_ip string|nil @The IP of the client
---@field public nonce string|nil @The nonce for use in CONNECT
---@field public cluster string|nil @The name of the cluster
---@field public domain string|nil @The configured NATS domain of the server
---@field public xkey string|nil @The public key of a designated XKey (x25519) used for encrypting authorization payloads
---@field public new fun(info_s: string):NatsServerInfo @returns an instance of the class
---@field private _check_required_params fun():void @checks required parameters
---@field private _parse_msg_info fun(key: string, value: string|number|boolean|string[]):void @recognizes server parameters
local NatsServerInfo = {}
NatsServerInfo.__index = NatsServerInfo

---@param info_s string @json string with nats server parameters
---@return NatsServerInfo @class instance
function NatsServerInfo.new(info_s)
    ---@type NatsServerInfo
    local self = setmetatable({}, NatsServerInfo)
    for k, v in pairs(json.decode(info_s)) do
        self:_parse_msg_info(k, v)
    end
    self:_check_required_params()
    return self
end

---@param self NatsServerInfo @class instance
---@return void
function NatsServerInfo._check_required_params(self)
    assert(self.server_id ~= nil, 'In the message of type info there must be a parameter server_id')
    assert(self.server_name ~= nil, 'In the message of type info there must be a parameter server_name')
    assert(self.version ~= nil, 'In the message of type info there must be a parameter version')
    assert(self.go ~= nil, 'In the message of type info there must be a parameter go')
    assert(self.host ~= nil, 'In the message of type info there must be a parameter host')
    assert(self.port ~= nil, 'In the message of type info there must be a parameter port')
    assert(self.headers ~= nil, 'In the message of type info there must be a parameter headers')
    assert(self.max_payload ~= nil, 'In the message of type info there must be a parameter max_payload')
    assert(self.proto ~= nil, 'In the message of type info there must be a parameter proto')
end

---@param self NatsServerInfo @class instance
---@param key string @nats server parameter name
---@param value string|number|boolean|string[] @nats server parameter value
---@return void
function NatsServerInfo._parse_msg_info(self, key, value)
    if key == 'server_id' then
        self.server_id = tostring(value)
    elseif key == 'server_name' then
        self.server_name = tostring(value)
    elseif key == 'version' then
        self.version = Version.new(value)
    elseif key == 'go' then
        self.go = Version.new(value:lstrip('go'))
    elseif key == 'host' then
        self.host = tostring(value)
    elseif key == 'port' then
        self.port = tonumber(value)
    elseif key == 'headers' then
        self.headers = value
    elseif key == 'max_payload' then
        self.max_payload = tonumber(value)
    elseif key == 'proto' then
        self.proto = tonumber(value)
    elseif key == 'client_id' then
        self.client_id = tonumber(value)
    elseif key == 'auth_required' then
        self.auth_required = value
    elseif key == 'tls_required' then
        self.tls_required = value
    elseif key == 'tls_verify' then
        self.tls_verify = value
    elseif key == 'tls_available' then
        self.tls_available = value
    elseif key == 'connect_urls' then
        self.connect_urls = {}
        for _, v in ipairs(value) do
            table.insert(self.connect_urls, uri.parse(v))
        end
    elseif key == 'ws_connect_urls' then
        self.ws_connect_urls = {}
        for _, v in ipairs(value) do
            table.insert(self.ws_connect_urls, uri.parse(v))
        end
    elseif key == 'ldm' then
        self.ldm = value
    elseif key == 'git_commit' then
        self.git_commit = tostring(value)
    elseif key == 'jetstream' then
        self.jetstream = value
    elseif key == 'ip' then
        self.ip = tostring(value)
    elseif key == 'client_ip' then
        self.client_ip = tostring(value)
    elseif key == 'nonce' then
        self.nonce = tostring(value)
    elseif key == 'cluster' then
        self.cluster = tostring(value)
    elseif key == 'domain' then
        self.domain = tostring(value)
    elseif key == 'xkey' then
        self.xkey = tostring(value)
    end
end


return NatsServerInfo
