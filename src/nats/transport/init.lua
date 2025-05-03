
---@class Transport abstract class to implement custom transports
---@field public new fun(host: string, port: number, timeout: number, msg_len: number):TCPTransport class constructor
---@field public connect fun(self: Transport):Result connects to socket
---@field public reconnect fun(self: Transport):Result reconnects to socket
---@field public write fun(self: Transport, payload: string):Result writes data to socket
---@field public read fun(self: Transport, len: number, timeout: number):Result reads data from socket
---@field public drain fun(self: Transport):Result blocks write until all data is written
---@field public close fun(self: Transport):Result stops the socket
---@field public health_check fun(self: Transport):Result returns false if the connection is closed, otherwise true

return {
    TCPTransport = require('nats.transport.tcp')
}
