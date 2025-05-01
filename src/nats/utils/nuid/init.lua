local math = require('math')

math.randomseed(os.time())



---@type table<string, string|number>
local constants = {
    DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
    PREFIX_LENGTH = 12,
    SEQ_LENGTH = 10,
    MAX_SEQ = 839299365868340224,
    MIN_INC = 33,
    MAX_INC = 333
}

constants.BASE = #constants.DIGITS
constants.INC = constants.MAX_INC - constants.MIN_INC
constants.TOTAL_LENGTH = constants.PREFIX_LENGTH + constants.SEQ_LENGTH

---@class Nuid class generating random strings
---@field private _seq number random sequence
---@field private _inc number random increment
---@field private _prefix string random prefix
---@field private _randomize_prefix function generates random prefix
---@field private _reset_sequential function resets sequences
---@field public new function returns an instance of the class
---@field public next function returns random string
local Nuid = {}
Nuid.__index = Nuid


---@return Nuid # instance of class Nuid
function Nuid.new()
    local self = setmetatable({}, Nuid)
    self:_randomize_prefix()
    self:_reset_sequential()
    return self
end

---@param self Nuid instance of class Nuid
---@return nil
function Nuid._randomize_prefix(self)
    local tmp_t = {}
    for _ = 1, constants.PREFIX_LENGTH, 1 do
        local char_number = math.random(1, constants.BASE)
        table.insert(tmp_t, constants.DIGITS:sub(char_number, char_number))
    end
    self._prefix = table.concat(tmp_t)
end

---@param self Nuid instance of class Nuid
---@return nil
function Nuid._reset_sequential(self)
    self._seq = math.random(0, constants.MAX_SEQ)
    self._inc = constants.MIN_INC + math.random(0, constants.INC)
end

---@param self Nuid instance of class Nuid
---@return string
function Nuid.next(self)
    self._seq = self._seq + self._inc
    if self._seq >= constants.MAX_SEQ then
        self:_randomize_prefix()
        self:_reset_sequential()
    end
    local l = self._seq
    local tmp_t = { self._prefix }
    for _ = 1, constants.SEQ_LENGTH, 1 do
        local char_number = l % constants.BASE
        table.insert(tmp_t, constants.DIGITS:sub(char_number, char_number))
        l = l / constants.BASE
        l = l - l % 1
    end
    return table.concat(tmp_t)
end


return Nuid
