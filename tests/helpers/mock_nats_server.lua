local socket = require("socket")

---@class MockNatsServer mock NATS server
---@field host string
---@field port number
---@field server_info table
---@field cb fun(sock:userdata, from:table, host:string, port:number, server_info:table):void
---@field socket userdata
local MockNatsServer = {}
MockNatsServer.__index = MockNatsServer


---@param host string
---@param port number
---@param server_info table
---@param fun fun(sock:userdata, from:table, host:string, port:number, server_info:table):void
function MockNatsServer.new(host, port, server_info, fun)
    local self = setmetatable({}, MockNatsServer)
    self.host = host
    self.port = port
    self.server_info = server_info
    self.cb = fun
    return self
end

function MockNatsServer.start(self)
    if self.server_info.host == nil then
        self.server_info.host = self.host
    end
    if self.server_info.port == nil then
        self.server_info.port = self.port
    end
    self.socket = socket.tcp_server(
            self.host,
            self.port,
            {
                name = self.server_info.name,
                prepare = function(sock)
                    sock:setsockopt('SOL_SOCKET','SO_REUSEADDR',true)
                    return 1024
                end,
                handler = function(sock, from)
                    self.cb(sock, from, self.host, self.port, self.server_info)
                end
            }
    )
end

function MockNatsServer.stop(self)
    self.socket:close()
end


return MockNatsServer
