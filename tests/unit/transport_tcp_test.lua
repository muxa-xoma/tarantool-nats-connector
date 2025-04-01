local t = require('luatest')
local socket = require('socket')

local helper = require('tests.helpers.unit')

local TCPTransport = require('nats.transport.tcp')
local errors = require('nats.utils.errors')


local group =  t.group('module-transport-tcp')

group.before_all(
        function(cg)
            cg.helper = helper
            cg.host = '127.0.0.1'
            cg.port = 3333
            cg.timeout = 1
            cg.delimiter = '\n'
            cg.cache = {}
        end
)

group.before_each(
        function(cg)
            cg.server = socket.tcp_server(
                    cg.host,
                    cg.port,
                    {
                        handler = function(sock)
                            while true do
                                local request = sock:read(cg.delimiter)
                                if request == "" or request == nil then
                                    break
                                end
                                table.insert(cg.cache, request)
                                sock:write('Request: ' .. request)
                            end
                        end,
                        prepare = function(sock)
                            table.clear(cg.cache)
                            sock:setsockopt('SOL_SOCKET','SO_REUSEADDR',true)
                        end
                    }
            )
        end
)

group.after_each(
        function(cg)
            cg.server:close()
        end
)

group.test_new = function(cg)
    local result = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(result.success)
    t.assert_not(result.error)
    t.assert_type(result.data, 'table')
end

group.test_new_error = function(cg)
    local result = TCPTransport.new('168.168.158.1', cg.port, 0.2)
    t.assert_not(result.success)
    t.assert_equals(result.error.code, 29)
    t.assert_str_contains(result.error.message, 'TCP transport error:')
    t.assert_not(result.data)
end

group.test_reconnect = function(cg)
    local result = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(result.success)
    local recon = result.data:reconnect()
    t.assert(recon.success)
    t.assert_not(recon.error)
end

group.test_reconnect_error = function(cg)
    local result = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(result.success)
    result.data._host = '168.168.158.1'
    local recon = result.data:reconnect()
    t.assert_not(recon.success)
    t.assert_equals(recon.error.code, 29)
    t.assert_str_contains(recon.error.message, 'TCP transport error:')
end

group.test_write = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    t.assert_equals(#(payload .. cg.delimiter), write.data)
    t.assert_equals('Request: ' .. payload .. cg.delimiter, con.data:read(cg.delimiter, 1).data)
    t.assert_equals(payload .. cg.delimiter, cg.cache[1])
end

group.test_write_err = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    con.data:drain()
    local write = con.data:write(payload .. cg.delimiter)
    t.assert_not(write.success)
    t.assert_equals(write.error.code, 29)
    t.assert_str_contains(write.error.message, 'TCP transport error:')
end

group.test_read = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local read = con.data:read(cg.delimiter, 1)
    t.assert(read.success)
    t.assert_equals('Request: ' .. payload .. cg.delimiter, read.data)
    t.assert_equals(payload .. cg.delimiter, cg.cache[1])
end

group.test_health_check_true = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    t.assert(con.data:health_check())
    local read = con.data:read(cg.delimiter, 1)
    t.assert(read.success)
    t.assert_equals('Request: ' .. payload .. cg.delimiter, read.data)
    t.assert_equals(payload .. cg.delimiter, cg.cache[1])
end

group.test_drain = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:drain()
    t.assert(response.success)
    local read = con.data:read(cg.delimiter, 1)
    t.assert(read.success)
    t.assert_equals(read.data, '')
end

group.test_drain_false_is_drain = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:drain()
    t.assert(response.success)
    local res = con.data:drain()
    t.assert_not(res.success)
    t.assert_equals(res.error.message, 'TCP transport error: socket is drain')
end

group.test_drain_false_is_close = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:close()
    t.assert(response.success)
    local res = con.data:drain()
    t.assert_not(res.success)
    t.assert_equals(res.error.message, 'TCP transport error: socket is close')
end

group.test_close = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:close()
    t.assert(response.success)
    t.assert(response.data)
end

group.test_close_drain = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:drain()
    t.assert(response.success)
    local res = con.data:close()
    t.assert(res.success)
    t.assert(res.data)
end

group.test_close_false = function(cg)
    local payload = cg.helper:random_string(cg.helper.random_int(5, 50))
    local con = TCPTransport.new(cg.host, cg.port, cg.timeout)
    t.assert(con.success)
    local write = con.data:write(payload .. cg.delimiter)
    t.assert(write.success)
    local response = con.data:close()
    t.assert(response.success)
    local res = con.data:close()
    t.assert_not(res.success)
end
