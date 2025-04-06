local uri = require('uri')

local server_info = require('nats.protocol.server_info')


---@class NatsServer class for client work with nats servers
---@field public uri URI connection parameters
---@field public reconnects number number of attempts to connect to the server
---@field public did_connect boolean need to connect to server
---@field public discovered boolean is the server found
---@field public info NatsServerInfo|void information returned by the server
---@field public tls_name string|void server name for tls
local M = {}
M.__index = M

---@param url_string string url for connecting to nats server
---@return NatsServer class instance
function M.new(url_string)
    ---@type NatsServer
    local self = setmetatable({}, M)
    ---@type URI
    self.uri = uri.parse(url_string)
    self.reconnects = 0
    self.did_connect = false
    self.discovered = false
    return self
end

---@param self NatsServer class instance
---@param server_info_string string json string with server information
---@return void
function M.set_server_info(self, server_info_string)
    self.info = server_info.new(server_info_string)
end

---@param self NatsServer class instance
---@param tls_name string server tls name
---@return void
function M.set_tls_name(self, tls_name)
    self.tls_name = tls_name
end

---@param self NatsServer class instance
---@return void
function M.need_connecting(self)
    self.did_connect = true
end

---@param self NatsServer class instance
---@return void
function M.server_discovered(self)
    self.discovered = true
end

---@param self NatsServer class instance
---@return string
function M.server_version(self)
    if self.info then
        return string.format('NATS server %s on golang go%s', self.info.version:tostring(), self.info.go:tostring())
    end
    return 'Unknown version for NATS server'
end


return M
