---@class Result a class representing the result of executing a function
---@field public success boolean
---@field public data any data returned by the function
---@field public error Error|nil the error that the function returned
---@field public new fun(data: any, err: Error|nil, add_err_text: string|nil):Result returns an instance of the class
local Result = {}
Result.__index = Result

---@param data any data returned by the function
---@param err Error|nil the error that the function returned
---@param add_err_text string|nil text added to the error text
function Result.new(data, err, add_err_text)
    local self = setmetatable({}, Result)
    if data then
        self.success = true
        self.data = data
    elseif err then
        self.success = false
        local err_t = table.deepcopy(err)
        if add_err_text then
            err_t.message = err_t.message .. add_err_text
        end
        self.error = err_t
    end
    return self
end

return Result
