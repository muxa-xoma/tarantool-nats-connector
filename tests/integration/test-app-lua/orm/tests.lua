local uuid = require('uuid')
local datetime = require('datetime')


---@class TestsORM @ORM for space tests
---@field private _name string @ORM name
---@field private _space userdata @ORM space
---@field private _pk_idx userdata @ORM primary index
---@field private _idx table @ORM index map
---@field private _logger userdata @ORM logger
---@field public state table<string, number> @ORM state map
---@field private _create fun(self: TestsORM, func: fun(): boolean, userdata): table<boolean, userdata> @ORM create test
---@field private _update fun(self: TestsORM, func: fun(): boolean, userdata): table<boolean, userdata> @ORM update test
---@field private _delete fun(self: TestsORM, id: userdata): table<boolean, userdata|string> @ORM delete test
---@field public new fun(name: string): TestsORM @ORM constructor
---@field public added fun(self: TestsORM, type: string, parameters: table<string, any>, state: number|nil): table<boolean, userdata> @ORM create test
---@field public started fun(self: TestsORM, id: userdata, started_at: userdata|nil, state: number|nil): table<boolean, userdata|string> @ORM start test
---@field public finished fun(self: TestsORM, id: userdata, result: table<string, any>|nil, finished_at: userdata|nil): table<boolean, userdata|string> @ORM finish test
---@field public error fun(self: TestsORM, id: userdata, result: table<string, any>|nil, finished_at: userdata|nil): table<boolean, userdata|string> @ORM error test
local TestsORM = {
    state = {
        added = 1,
        started = 2,
        finished = 3,
        error = 4,
    }
}
TestsORM.__index = TestsORM

---@param name string @Space name
---@return TestsORM @ORM instance
function TestsORM.new(name, logger)
    if name == nil or name == "" then
        error("Invalid argument: name must not be empty")
    end
    local self = setmetatable({}, TestsORM)
    self._name = name
    self._logger = logger or require('log').new('tests-orm')
    self:_create_space()
    return self
end

---@param self TestsORM @ORM instance
---@return void
function TestsORM._create_space(self)
    self._space = box.schema.create_space(self._name, {
        format = {
            {
                name = 'id',
                type = 'uuid',
                is_nullable = false
            },
            {
                name = 'type',
                type = 'string',
                is_nullable = false
            },
            {
                name = 'parameters',
                type = 'map',
                is_nullable = false
            },
            {
                name = 'state',
                type = 'unsigned',
                is_nullable = false
            },
            {
                name = 'started_at',
                type = 'datetime',
                is_nullable = true
            },
            {
                name = 'finished_at',
                type = 'datetime',
                is_nullable = true
            },
            {
                name = 'result',
                type = 'map',
                is_nullable = true
            }
        },
        if_not_exists = true,
        engine = 'memtx'
    })
    self._pk_idx = self._space:create_index(self._name .. '_pk', {
        parts = {'id'},
        unique = true,
        type = 'tree',
        if_not_exists = true
    })
    self._idx = {
        id = 1,
        type = 2,
        parameters = 3,
        state = 4,
        started_at = 5,
        finished_at = 6,
        result = 7
    }
end

---@param self TestsORM @ORM instance
---@param func fun(): boolean, userdata @function to execute
---@return table<boolean, userdata> @returns true and test id if ok
function TestsORM._create(self, func)
    assert(func, "Function must be provided")
    local ok, data = pcall(func)
    local count = 5
    while not ok and count > 0 do
        if data:unpack().code == box.error.TUPLE_FOUND then
            self._logger.error("Test already exists")
        end
        count = count - 1
        ok, data = pcall(func)
    end
    if not ok then
        self._logger.error("Failed to insert test: %s", data)
        return { false, data }
    else
        return { true, data[1] }
    end
end

---@param self TestsORM @ORM instance
---@param func fun(): boolean, userdata @function to execute
---@return table<boolean, userdata> @returns true and test id if ok
function TestsORM._update(self, func)
    assert(func, "Function must be provided")
    local ok, data = pcall(func)
    local count = 5
    while not ok and count > 0 do
        count = count - 1
        ok, data = pcall(func)
    end
    if not ok then
        self._logger.error("Failed to update test: %s", data)
        return { false, data }
    elseif not data then
        self._logger.error("Test not found")
        return { false, "Test not found" }
    else
        return { true, data[self._idx.id] }
    end
end

---@param self TestsORM @ORM instance
---@param id userdata @test id
---@return table<boolean, userdata|string> @returns true and test id if ok
function TestsORM._delete(self, id)
    assert(id, "Test id must be provided")
    local ok, data = pcall(function()
        return self._pk_idx:delete(id)
    end)
    if not ok then
        self._logger.error("Failed to delete test: %s", data)
        return { false, data }
    elseif not data then
        self._logger.error("Test with id %s not found", id)
        return { false, "Test not found" }
    else
        return { true, data[self._idx.id] }
    end
end

---@param self TestsORM @ORM instance
---@param type string @type of test
---@param parameters table<string, any> @test options
---@param state number|nil @test state
---@return table<boolean, userdata> @returns true and test id if ok
function TestsORM.added(self, type, parameters, state)
    state = state or self.state.added
    local create_fn = function()
        return self._space:insert{
            uuid(), type, parameters, state
        }
    end
    return self:_create(create_fn)
end

---@param self TestsORM @ORM instance
---@param id userdata @test id
---@param started_at userdata|nil @test started time
---@param state number|nil @test state
---@return table<boolean, userdata|string> @returns true and test id if ok
function TestsORM.started(self, id, started_at, state)
    started_at = started_at or datetime.now()
    state = state or self.state.started
    local update_fn = function()
        return self._pk_idx:update(id, {
            { '=', self._idx.state, state },
            { '=', self._idx.started_at, started_at }
        })
    end
    return self:_update(update_fn)
end

---@param self TestsORM @ORM instance
---@param id userdata @test id
---@param result table<string, any> @test result
---@param finished_at userdata|nil @test finished time
function TestsORM.finished(self, id, result, finished_at)
    finished_at = finished_at or datetime.now()
    local update_fn = function()
        return self._pk_idx:update(id, {
            { '=', self._idx.result, result },
            { '=', self._idx.finished_at, finished_at },
            { '=', self._idx.state, self.state.finished }
        })
    end
    return self:_update(update_fn)
end

---@param self TestsORM @ORM instance
---@param id userdata @test id
---@param result table<string, any> @test result
---@param finished_at userdata|nil @test finished time
function TestsORM.error(self, id, result, finished_at)
    finished_at = finished_at or datetime.now()
    local update_fn = function()
        return self._pk_idx:update(id, {
            { '=', self._idx.result, result },
            { '=', self._idx.finished_at, finished_at },
            { '=', self._idx.state, self.state.error }
        })
    end
    self:_update(update_fn)
end

---@param self TestsORM @ORM instance
---param id userdata @test id
---return table<boolean, table|string> @returns true and test tuple if ok
function TestsORM.get(self, id)
    local ok, data = pcall(function()
        return self._pk_idx:get(id)
    end)
    if not ok then
        self._logger.error("Failed to get test: %s", data)
        return { false, tostring(data) }
    elseif not data then
        self._logger.error("Test with id %s not found", id)
        return { false, "Test not found" }
    else
        return { true, data }
    end
end

---@param self TestsORM @ORM instance
---param id userdata @test id
---param result table<string, any> @test result
---return table<boolean, table|string> @returns true and test tuple if ok
function TestsORM.update_result(self, id, result)
    local update_fn = function()
        return self._pk_idx:update(id, {
            { '=', self._idx.result, result }
        })
    end
    return self:_update(update_fn)
end


return TestsORM