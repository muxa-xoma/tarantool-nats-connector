local uri = require('uri')

local NatsServerInfo = require('nats.protocol.server_info')


---@class NatsServer @class for client work with nats servers
---@field public uri URI @connection parameters
---@field public reconnects number @number of attempts to connect to the server
---@field public did_connect boolean @need to connect to server
---@field public discovered boolean @is the server found
---@field public info NatsServerInfo|void @information returned by the server
---@field public tls_name string|void @server name for tls
---@field public last_attempt number|void @time of last connection attempt
---@field public new fun(string):NatsServer @returns an instance of the class
---@field public set_server_info fun(string):void @sets server parameters
---@field public set_tls_name fun(string):void @sets tls name
---@field public need_connecting fun():void @marks as needing connection
---@field public server_discovered fun():void @marks as detected
---@field public server_version fun():string @return server version string
local NatsServer = {}
NatsServer.__index = NatsServer

---@param url_string string @url for connecting to nats server
---@return NatsServer @class instance
function NatsServer.new(url_string)
    ---@type NatsServer
    local self = setmetatable({}, NatsServer)
    ---@type URI
    self.uri = uri.parse(url_string)
    self.reconnects = 0
    self.did_connect = false
    self.discovered = false
    return self
end

---@param self NatsServer @class instance
---@param server_info_string string @json string with server information
---@return void
function NatsServer.set_server_info(self, server_info_string)
    self.info = NatsServerInfo.new(server_info_string)
end

---@param self NatsServer @class instance
---@param tls_name string @server tls name
---@return void
function NatsServer.set_tls_name(self, tls_name)
    self.tls_name = tls_name
end

---@param self NatsServer @class instance
---@return void
function NatsServer.need_connecting(self)
    self.did_connect = true
end

---@param self NatsServer @class instance
---@return void
function NatsServer.server_discovered(self)
    self.discovered = true
end

---@param self NatsServer @class instance
---@return string @server version string
function NatsServer.server_version(self)
    if self.info then
        return string.format('NATS server %s on golang go%s', self.info.version:tostring(), self.info.go:tostring())
    end
    return 'Unknown version for NATS server'
end


return NatsServer
