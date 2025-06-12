

---@class MessagesORM @ORM for space messages
---@field private _name string @ORM space name
---@field private _logger userdata @ORM logger
---@field private _space userdata @ORM space
---@field private _pk_idx userdata @ORM primary key index
---@field private _reply_to_idx userdata @ORM reply to index
---@field private _test_id_idx userdata @ORM test id index
---@field private _idx table<string, number> @ORM index map
---@field private _create fun(self: TestsORM, func: fun(): boolean, userdata): table<boolean, userdata> @ORM create message
---@field private _update fun(self: TestsORM, func: fun(): boolean, userdata): table<boolean, userdata> @ORM update message
---@field private _delete fun(self: TestsORM, id: userdata): table<boolean, userdata|string> @ORM delete message
local MessagesORM = {}
MessagesORM.__index = MessagesORM


---@param name string @Space name
---@return MessagesORM @ORM instance
function MessagesORM.new(name, logger)
    if name == nil or name == "" then
        error("Invalid argument: name must not be empty")
    end
    local self = setmetatable({}, MessagesORM)
    self._name = name
    self._logger = logger or require('log').new('messages-orm')
    self:_create_space()
    return self
end

---@param self MessagesORM @ORM instance
---@return void
function MessagesORM._create_space(self)
    self._space = box.schema.create_space(self._name, {
        format = {
            {
                name = 'test_id',
                type = 'uuid',
                is_nullable = false
            },
            {
                name = 'id',
                type = 'uuid',
                is_nullable = false
            },
            {
                name = 'subject',
                type = 'string',
                is_nullable = false
            },
            {
                name = 'payload',
                type = 'map',
                is_nullable = false
            },
            {
                name = 'headers',
                type = 'map',
                is_nullable = true
            },
            {
                name = 'reply',
                type = 'string',
                is_nullable = true
            },
            {
                name = 'reply_to',
                type = 'uuid',
                is_nullable = true
            },
            {
                name = 'published_at',
                type = 'datetime',
                is_nullable = true
            },
            {
                name = 'received_at',
                type = 'datetime',
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
    self._reply_to_idx = self._space:create_index(self._name .. '_reply_to_idx', {
        parts = {'reply_to'},
        type = 'tree',
        unique = false,
        if_not_exists = true
    })
    self._test_id_idx = self._space:create_index(self._name .. '_test_id_idx', {
        parts = {'test_id'},
        type = 'tree',
        unique = false,
        if_not_exists = true
    })
    self._idx = {
        test_id = 1,
        id = 2,
        subject = 3,
        payload = 4,
        headers = 5,
        reply = 6,
        reply_to = 7,
        published_at = 8,
        received_at = 9
    }
end

---@param self MessagesORM @ORM instance
---@param func fun(): boolean, userdata @function to execute
---@return table<boolean, userdata> @returns true and test id if ok
function MessagesORM._create(self, func)
    assert(func, "Function must be provided")
    local ok, data = pcall(func)
    local count = 5
    while not ok and count > 0 do
        if data:unpack().code == box.error.TUPLE_FOUND then
            self._logger.error("Message already exists")
        end
        count = count - 1
        ok, data = pcall(func)
    end
    if not ok then
        self._logger.error("Failed to insert message: %s", data)
        return { false, data }
    else
        return { true, data[1] }
    end
end

---@param self MessagesORM @ORM instance
---@param func fun(): boolean, userdata @function to execute
---@return table<boolean, userdata> @returns true and message id if ok
function MessagesORM._update(self, func)
    assert(func, "Function must be provided")
    local ok, data = pcall(func)
    local count = 5
    while not ok and count > 0 do
        count = count - 1
        ok, data = pcall(func)
    end
    if not ok then
        self._logger.error("Failed to update message: %s", data)
        return { false, data }
    elseif not data then
        self._logger.error("Message not found")
        return { false, "Message not found" }
    else
        return { true, data[self._idx.id] }
    end
end

---@param self MessagesORM @ORM instance
---@param id userdata @Test id
---@return table<boolean, userdata> @returns true and message id if ok
function MessagesORM._delete(self, id)
    assert(id, "Message id must be provided")
    local ok, data = pcall(function()
        return self._pk_idx:delete(id)
    end)
    if not ok then
        self._logger.error("Failed to delete message: %s", data)
        return { false, data }
    elseif not data then
        self._logger.error("Message with id %s not found", id)
        return { false, "Message not found" }
    else
        return { true, data[self._idx.id] }
    end
end

---@param self MessagesORM @ORM instance
---@param test_id userdata @Test id
---@param id userdata @Message id
---@param subject string @Message subject
---@param payload table<string, any> @Message payload
---@param headers table<string, string> @Message headers
---@param reply string @Message reply
---@param reply_to userdata @Message reply to message id
---@param published_at userdata @Message published at
---@param received_at userdata @Message received at
---@return table<boolean, userdata> @returns true and message id if ok
function MessagesORM.add(self, test_id, id, subject, payload, headers, reply, reply_to, published_at, received_at)
    local insert_fn = function()
        return self._space:insert{
            test_id, id, subject, payload, headers, reply, reply_to, published_at, received_at
        }
    end
    return self:_create(insert_fn)
end

---@param self MessagesORM @ORM instance
---@param id userdata @Message id
---@param received_at userdata @Message received at
---@return table<boolean, userdata> @returns true and message id if ok
function MessagesORM.received_at(self, id, received_at)
    local update_fn = function()
        return self._pk_idx:update(id, {{'=', self._idx.received_at, received_at}})
    end
    return self:_update(update_fn)
end

---@param self MessagesORM @ORM instance
---param id userdata @message id
---return table<boolean, table|string> @returns true and message tuple if ok
function MessagesORM.get(self, id)
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


return MessagesORM
