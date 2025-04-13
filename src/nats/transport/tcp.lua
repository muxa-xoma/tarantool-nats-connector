local socket = require('socket')

local errors = require('nats.utils.errors')
local result = require('nats.utils.result')

---@class TCPTransport the class is present TCP socket
---@field private _socket table socket object
---@field private _timeout number action timeout
---@field private _host string IP address or DNS name
---@field private _port number socket port
---@field private _default_msg_len number default number of bytes to read
---@field private _has_drain boolean socket is drain
---@field private _has_close boolean socket is close
---@field public new function returns an instance of the class
---@field public connect function connects to socket
---@field public reconnect function reconnects to socket
---@field public write function writes data to the socket
---@field public read function reads data from socket
---@field public drain function locks socket for writing
---@field public close function closes the socket
---@field public health_check function checks socket status
local M = {}
M.__index = M


---@param host string connection hostname or IP address
---@param port number connection port
---@param timeout number connection timeout, default 1 second
---@param msg_len number default number of bytes to read
---@return TCPTransport instance of class TCPTransport
function M.new(host, port, timeout, msg_len)
    local self = setmetatable({}, M)
    self._timeout = timeout and timeout or 1
    self._host = host
    self._port = port
    self._default_msg_len = msg_len and msg_len or 32768
    return self
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data is TCPTransport
function M.connect(self)
    local con, err = socket.tcp_connect(self._host, self._port, self._timeout)
    if err ~= nil then
        return result.new(nil, errors.tcp_transport, err)
    end
    self._socket = con
    return result.new(true)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data is TCPTransport
function M.reconnect(self)
    return self:connect()
end

---@param self TCPTransport instance of class TCPTransport
---@param payload string message being sent
---@return Result instance of class Result where data is number of write bites
function M.write(self, payload)
    local bite_n = self._socket:write(payload)
    if not bite_n then
        return result.new(nil, errors.tcp_transport, self._socket:error())
    end
    return result.new(bite_n)
end

---@param self TCPTransport instance of class TCPTransport
---@param len number number of read bits
---@return Result instance of class Result where data is read string
function M.read(self, len, timeout)
    len = len and len or self._default_msg_len
    timeout = timeout and timeout or self._timeout
    local payload_s = self._socket:read({ chunk = len, delimiter = '\r\n' }, timeout)
    if not payload_s then
        return result.new(nil, errors.tcp_transport, self._socket:error())
    end
    return result.new(payload_s)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function M.drain(self)
    if self._has_drain then
        return result.new(nil, errors.tcp_transport, 'socket is drain')
    end
    if self._has_close then
        return result.new(nil, errors.tcp_transport, 'socket is close')
    end
    local has_shutdown = self._socket:shutdown(socket.SHUT_WR)
    if not has_shutdown then
        return result.new(nil, errors.tcp_transport, self._socket:error())
    end
    self._has_drain = true
    return result.new(has_shutdown)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function M.close(self)
    if self._has_close then
        return result.new(nil, errors.tcp_transport, 'socket is close')
    end
    local has_close = self._socket:close()
    if not has_close then
        return result.new(nil, errors.tcp_transport, self._socket:error())
    end
    self._has_close = true
    return result.new(has_close)
end

---@param self TCPTransport instance of class TCPTransport
---@return Result instance of class Result where data boolean
function M.health_check(self)
    if self._has_drain then
        return result.new(nil, errors.tcp_transport, 'socket is drain')
    end
    if self._has_close then
        return result.new(nil, errors.tcp_transport, 'socket is close')
    end
    local has_healthy = self._socket:readable(self._timeout) and self._socket:writable(self._timeout)
    if not has_healthy then
        return result.new(nil, errors.tcp_transport, self._socket:error())
    end
    return result.new(has_healthy)
end


return M
