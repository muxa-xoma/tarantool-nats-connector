local json =require('json')

local versions = require('nats.version')
local version = require('nats.utils.version')
local result = require('nats.utils.result')
local errors = require('nats.utils.errors')


---@class NatsConnectionParameters
---@field public verbose boolean Turns on +OK protocol acknowledgements.
---@field public pedantic boolean Turns on additional strict format checking, e.g. for properly formed subjects.
---@field public tls_required boolean Indicates whether the client requires an SSL connection.
---@field public lang Version The implementation language of the client.
---@field public version Version The version of the client.
---@field public echo boolean If set to false, the server (version 1.2.0+) will not send originating messages from this connection to its own subscriptions. Clients should set this to false only for server supporting this feature, which is when proto in the INFO protocol is set to at least 1.
---@field public name string|void Client name.
---@field public auth_token string|void Client authorization token.
---@field public user string|void Connection username.
---@field public pass string|void Connection password.
---@field public protocol number|void Sending 0 (or absent) indicates client supports original protocol. Sending 1 indicates that the client supports dynamic reconfiguration of cluster topology changes by asynchronously receiving INFO messages with known servers it can reconnect to.
---@field public sig string|void In case the server has responded with a nonce on INFO, then a NATS client must use this field to reply with the signed nonce.
---@field public jwt string|void The JWT that identifies a user permissions and account.
---@field public no_responders boolean Enable quick replies for cases where a request is sent to a topic with no responders.
---@field public headers boolean Whether the client supports headers.
---@field public nkey string|void The public NKey to authenticate the client. This will be used to verify the signature (sig) against the nonce provided in the INFO message.
---@field public new function returns an instance of the class
---@field public tostring function returns as json string
---@field public set_server_info_params function sets server parameters
local M = {}
M.__index = M

---@param name string|void Client name.
---@param user string|void Connection username.
---@param password string|void Connection password.
---@param auth_token string|void Client authorization token.
---@param jwt string|void The JWT that identifies a user permissions and account.
---@param nkey string|void The public NKey to authenticate the client.
---@param echo boolean|void If set to false, the server will not send originating messages from this connection to its own subscriptions.
---@param no_responders boolean|void Enable quick replies for cases where a request is sent to a topic with no responders.
---@param verbose boolean|void Turns on +OK protocol acknowledgements.
---@param pedantic boolean|void Turns on additional strict format checking, e.g. for properly formed subjects.
---@param tls_required boolean|void Indicates whether the client requires an SSL connection.
---@return NatsConnectionParameters instance class
function M.new(name, user, password, auth_token, jwt, nkey, echo, no_responders, verbose, pedantic, tls_required)
    ---@type NatsConnectionParameters
    local self = setmetatable({}, M)
    self.verbose = verbose or false
    self.pedantic = pedantic or false
    self.tls_required = tls_required or false
    self.lang = version.new(versions.tarantool)
    self.version = version.new(versions.module)
    if echo ~= nil then
        self.echo = echo
    else
        self.echo = true
    end
    if no_responders ~= nil then
        self.no_responders = no_responders
    else
        self.no_responders = true
    end
    self.name = name or nil
    self.auth_token = auth_token or nil
    self.user = user or nil
    self.pass = password or nil
    self.jwt = jwt or nil
    self.headers = true
    self.nkey = nkey or nil
    return self
end

---@param self NatsConnectionParameters instance class
---@return Result where data json string for connect
function M.tostring(self)
    local connection_t = {
        verbose = self.verbose,
        pedantic = self.pedantic,
        tls_required = self.tls_required,
        lang = 'tarantool:' .. self.lang:tostring(),
        version = self.version:tostring(),
        echo = self.echo,
        no_responders = self.no_responders,
        headers = self.headers
    }
    if self.auth_token ~= nil then
        connection_t.auth_token = self.auth_token
    end
    if self.user ~= nil then
        connection_t.user = self.user
        connection_t.pass = self.pass
    end
    if self.name ~= nil then
        connection_t.name = self.name
    end
    if self.protocol ~= nil then
        connection_t.protocol = self.protocol
    end
    if self.sig ~= nil then
        connection_t.sig = self.sig
    end
    if self.jwt ~= nil then
        connection_t.jwt = self.jwt
    end
    if self.nkey ~= nil then
        connection_t.nkey = self.nkey
    end
    return result.new(json.encode(connection_t))
end

---@param self NatsConnectionParameters instance class
---@param params NatsServerInfo instance class
---@return Result where data json string for connect
function M.set_server_info_params(self, params)
    self.protocol = params.proto
    if self.protocol ~= 1 and not self.echo then
        return result.new(nil, errors.invalid_connect_params, ': server does not support disabling echo parameter')
    end
    self.sig = params.nonce or nil
    if params.auth_required and ((not self.user or not self.pass) and not self.auth_token) then
        return result.new(nil, errors.invalid_connect_params, ': server only supports authorized connections')
    end
    return self:tostring()
end


return M
