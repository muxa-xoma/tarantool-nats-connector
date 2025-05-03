local socket = require('socket')

local NatsErrorEnum = require('nats.utils.errors')
local Result = require('nats.utils.result')
local NatsProtocolConstants = require('nats.protocol.constants')

---@class TCPTransport the class is present TCP socket
---@field private _socket table socket object
---@field private _timeout number action timeout
---@field private _host string IP address or DNS name
---@field private _port number socket port
---@field private _default_msg_len number default number of bytes to read
---@field private _has_drain boolean socket is drain
---@field private _has_close boolean socket is close
---@field public new fun(host: string, port: number, timeout: number, msg_len: number):TCPTransport class constructor
---@field public connect fun(self: TCPTransport):Result connects to socket
---@field public reconnect fun(self: TCPTransport):Result reconnects to socket
---@field public write fun(self: TCPTransport,payload: string):Result writes data to socket
---@field public read fun(self: TCPTransport,len: number, timeout: number):Result reads data from socket
---@field public drain fun(self: TCPTransport):Result blocks write until all data is written
---@field public close fun(self: TCPTransport):Result stops the socket
---@field public health_check fun(self: TCPTransport):Result returns false if the connection is closed, otherwise true
local TCPTransport = {}
TCPTransport.__index = TCPTransport


---@param host string connection hostname or IP address
---@param port number connection port
---@param timeout number connection timeout, default 1 second
---@param msg_len number default number of bytes to read
---@return TCPTransport instance of class TCPTransport
function TCPTransport.new(host, port, timeout, msg_len)
    local self = setmetatable({}, TCPTransport)
    self._timeout = timeout and timeout or 1
    self._host = host
    self._port = port
    self._default_msg_len = msg_len and msg_len or 32768
    return self
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data is TCPTransport
function TCPTransport.connect(self)
    local con, err = socket.tcp_connect(self._host, self._port, self._timeout)
    if err ~= nil then
        return Result.new(nil, NatsErrorEnum.tcp_transport, err)
    end
    self._socket = con
    return Result.new(true)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data is TCPTransport
function TCPTransport.reconnect(self)
    return self:connect()
end

---@param self TCPTransport instance of class TCPTransport
---@param payload string message being sent
---@return Result instance of class Result where data is number of write bites
function TCPTransport.write(self, payload)
    local bite_n = self._socket:write(payload)
    if not bite_n then
        return Result.new(nil, NatsErrorEnum.tcp_transport, self._socket:error())
    end
    return Result.new(bite_n)
end

---@param self TCPTransport instance of class TCPTransport
---@param len number number of read bits
---@return Result instance of class Result where data is read string
function TCPTransport.read(self, len, timeout)
    len = len and len or self._default_msg_len
    local payload_s = self._socket:read({ chunk = len, delimiter = NatsProtocolConstants.delimiter }, timeout)
    if not payload_s then
        return Result.new(nil, NatsErrorEnum.tcp_transport, self._socket:error())
    elseif payload_s == '' then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'empty payload')
    end
    return Result.new(payload_s)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function TCPTransport.drain(self)
    if self._has_drain then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'socket is drain')
    end
    if self._has_close then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'socket is close')
    end
    local has_shutdown = self._socket:shutdown(socket.SHUT_WR)
    if not has_shutdown then
        return Result.new(nil, NatsErrorEnum.tcp_transport, self._socket:error())
    end
    self._has_drain = true
    return Result.new(has_shutdown)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function TCPTransport.close(self)
    if self._has_close then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'socket is close')
    end
    local has_close = self._socket:close()
    if not has_close then
        return Result.new(nil, NatsErrorEnum.tcp_transport, self._socket:error())
    end
    self._has_close = true
    return Result.new(has_close)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function TCPTransport.health_check(self)
    if self._has_drain then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'socket is drain')
    end
    if self._has_close then
        return Result.new(nil, NatsErrorEnum.tcp_transport, 'socket is close')
    end
    local has_healthy = self._socket:readable(self._timeout) and self._socket:writable(self._timeout)
    if not has_healthy then
        return Result.new(nil, NatsErrorEnum.tcp_transport, self._socket:error())
    end
    return Result.new(has_healthy)
end


return TCPTransport
