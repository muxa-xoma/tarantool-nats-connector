local log = require('log').new("test-app-lua")
local json = require('json')
local uuid = require('uuid')
local datetime = require('datetime')
local fiber = require('fiber')
local http_client = require('http.client')

local TestsORM = require('orm.tests')
local MessagesORM = require('orm.messages')

local nats = require('nats')


---@class TestNats @class for test nats connector
---@field private _result_url string @result url for reply to test service
---@field private _nc NatsClient @instance of NatsClient
---@field private _http userdata @instance of HttpClient
---@field private _tests TestsORM @instance of TestORM
---@field private _messages MessagesORM @instance of MessagesORM
---@field private _test_in_work userdata|nil @fiber for test
---@field private _result_test_publish fun(self: TestNats, id: userdata, err: boolean): void @publish test result
---@field private _generate_message fun(headers: table<userdata, userdata, number>|nil): table<string, userdata>, table<string, userdata|number> @generate message for test
---@field public new fun(servers: string|string[], options: table<string, any>|nil, result_url: string): TestNats @constructor
---@field public publish_test_start fun(self: TestNats, options: table<string, any>): table<boolean, userdata|string> @start request test
local TestNats = {}
TestNats.__index = TestNats


---@param servers string|string[] @servers list for connect to nats
---@param options table<string, any>|nil @connection parameters
---@param result_url string @url for reply to test service
---@returns TestNats @returns instance of TestNats
function TestNats.new(servers, options, result_url)
    local self = setmetatable({}, TestNats)
    if result_url == nil or result_url == '' or type(result_url) ~= 'string' then
        assert(false, "You must specify the result_url parameter")
    end
    if servers == nil or servers == '' or (type(servers) ~= 'string' and type(servers) ~= 'table') then
        assert(false, "You must specify the servers parameter")
    end
    if options ~= nil and type(options) ~= 'table' then
        assert(false, "The options parameter must be a table")
    end
    log.debug("Creating a new instance of TestNats with servers: %s, options: %s, result_url: %s", servers, json.encode(options), result_url)
    self._result_url = result_url
    self._nc = nats.NatsClient.new(servers, options)
    self._http = http_client.new()
    self._tests = TestsORM.new('tests', log)
    self._messages = MessagesORM.new('messages', log)
    log.debug("New instance of TestNats was created")
    return self
end

---@param self TestNats @instance of TestNats
---@param id userdata @test id (uuid)
---@param err boolean @true if error created or updated test tuple
---@return void
function TestNats._result_test_publish(self, id, err)
    err = err or false
    local body, response
    local count = 5
    local result = self._tests:get(id)
    if not result[1] then
        log.error("Test with id %s not found", id)
        body = { error = true, id = id }
    else
        body = {
            error = err,
            id = result[2][self._tests._idx.id],
            type = result[2][self._tests._idx.type],
            parameters = result[2][self._tests._idx.parameters],
            state = result[2][self._tests._idx.state],
            started_at = result[2][self._tests._idx.started_at],
            finished_at = result[2][self._tests._idx.finished_at],
            result = result[2][self._tests._idx.result]
        }
    end
    response = self._http:post(self._result_url, body)
    while response.status ~= 200 and count > 0 do
        fiber.sleep(0.5)
        count = count - 1
        response = self._http:post(self._result_url, body)
    end
    if response.status ~= 200 then
        log.error("Error publishing result to test service")
    else
        log.debug("Result published to test service")
    end
end

---@param headers table<userdata, userdata, number>|nil @headers for message
---@return table<string, userdata>, table<string, userdata|number> @returns payload and headers
function TestNats._generate_message(headers)
    local hdrs = headers and {
        test_id = tostring(headers[1]),
        start_time = tostring(headers[2]),
        msg_number = tostring(headers[3])
    } or nil
    local payload = {
        msg_id = uuid(),
        published_at = datetime.now()
    }
    return payload, hdrs
end

---@param self TestNats @instance of TestNats
---@param test_id userdata @test id (uuid)
---@param options table<string, any> @request test options
---@return void
function TestNats._publish_test_work(self, test_id, options)
    local result, err
    local start_time = datetime.now()
    local msg_count = 0
    fiber.new(self._tests.started, self._tests, test_id, start_time)
    if options.msg_count ~= nil then
        while msg_count < options.msg_count do
            msg_count = msg_count + 1
            local payload, headers = self._generate_message(options.headers and { test_id, start_time, msg_count } or nil)
            self._nc:publish(options.subject, json.encode(payload), options.reply, headers)
            fiber.new(
                    self._messages.add, self._messages, test_id, payload.msg_id, options.subject,
                    payload, headers, options.reply, nil, payload.published_at, nil
            )
            err = false
        end
    elseif options.work_time ~= nil then
        while start_time >= datetime.now():sub{ sec = options.work_time } do
            msg_count = msg_count + 1
            local payload, headers = self._generate_message(options.headers and { test_id, start_time, msg_count } or nil)
            self._nc:publish(options.subject, json.encode(payload), options.reply, headers)
            fiber.new(
                    self._messages.add, self._messages, test_id, payload.msg_id, options.subject,
                    payload, headers, options.reply, nil, payload.published_at, nil
            )
            err = false
        end
    else
        log.error("Test options are not valid")
        err = true
    end
    if err then
        result = self._tests:error(test_id, {error = "Test options are not valid"})
    else
        result = self._tests:finished(test_id, { msg_count = msg_count })
    end
    fiber.yield()
    if not result[1] then
        log.error("Failed to finish test: %s", result[2])
    else
        log.info("Test finished")
    end
    self:_result_test_publish(test_id, err)
end

---@param self TestNats @instance of TestNats
---@param options table<string, any> @request test options
---@return table<boolean, userdata|string> @returns result of request
function TestNats.publish_test_start(self, options)
    if type(options) ~= 'table' then
        return { false, "The options parameter must be a table" }
    end
    if options.subject == nil or options.subject == '' or type(options.subject) ~= 'string' then
        return { false, "You must specify the subject parameter" }
    end
    if options.headers == nil or type(options.headers) ~= 'boolean' then
        options.headers = false
    end
    if options.reply ~= nil and type(options.reply) ~= 'string' then
        options.reply = nil
    end
    if (options.msg_count == nil and options.work_time == nil) or (
            options.msg_count ~= nil and (type(options.msg_count) ~= 'number' or options.msg_count < 1)) or (
            options.work_time ~= nil and (type(options.work_time) ~= 'number' or options.work_time < 1)) then
        options.msg_count = 1000
    end
    if options.msg_count ~= nil then
        options.work_time = nil
    end
    if self._test_in_work ~= nil and self._test_in_work:status() ~= 'dead' then
        return { false, 'Test is already running' }
    end
    local create_test = self._tests:added('publish', options)
    if not create_test[1] then
        return { false, tostring(create_test[2]) }
    end
    self._test_in_work = fiber.new(self._publish_test_work, self, create_test[2], options)
    return { true, create_test[2] }
end

---@param self TestNats @instance of TestNats
---@param test_id userdata @test id (uuid)
---@param fibers_t userdata[] @table with fibers
---@return void
function TestNats._publish_test_report(self, test_id, fibers_t)
    local test_result = self._tests:get(test_id)
    local err = false
    if not test_result[1] then
        log.error("Test with id %s not found", test_id)
        err = true
    else
        test_result = test_result[2][self._tests._idx.result]
        test_result.received_msg_count = #fibers_t
        local worked_messages = {}
        for _, v in ipairs(fibers_t) do
            local result = v:join()
            if result[1] then
                table.insert(worked_messages, result[2])
            end
        end
        test_result.processed_msg_count = #worked_messages
        local max_time, min_time, avg_time = 0, 0, 0
        for _, v in ipairs(worked_messages) do
            local message = self._messages:get(v)
            if not message[1] then
                log.error("Message with id %s not found", v)
            else
                message = message[2]
                local time = message[self._messages._idx.received_at].timestamp - message[self._messages._idx.published_at].timestamp
                avg_time = avg_time + time
                if time > max_time then
                    max_time = time
                end
                if time < min_time then
                    min_time = time
                end
            end
        end
        test_result.max_time = max_time
        test_result.min_time = min_time
        test_result.avg_time = avg_time / test_result.processed_msg_count
        local result = self._tests:update_result(test_id, test_result)
        if not result[1] then
            log.error("Failed to update test result: %s", result[2])
            err = true
        end
    end
    self:_result_test_publish(test_id, err)
end

---@param self TestNats @instance of TestNats
---@param test_id userdata @test id (uuid)
---@param received_t table<userdata, userdata>[] @table with message id and time received
function TestNats.publish_test_end(self, test_id, received_t)
    local fibers = {}
    for _, v in ipairs(received_t) do
        local fb = fiber.new(self._messages.received_at, self._messages, v[1], v[2])
        fb:set_joinable(true)
        table.insert(fibers, fb)
    end
    fiber.new(self._publish_test_report, self, test_id, fibers)
    return { true, test_id }
end

---@param name string @name of test
---@param servers string[]|string @servers for nats
---@param options table<string, any> @options for nats
---@param result_url string @url for publishing results
local function create_test_nats(name, servers, options, result_url)
    rawset(_G, name, TestNats.new(servers, options, result_url))
    return true
end

rawset(_G, "create_test_nats", create_test_nats)