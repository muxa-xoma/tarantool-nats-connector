---@class Version the class is a version formed from a string
---@field public prefix string version prefix (can only be "v")
---@field public major number major version
---@field public minor number minor version
---@field public patch number patch version
---@field public pre_release number|nil pre-release version
---@field public hash string|nil commit hash
---@field public new function returns an instance of the class
---@field public tostring function returns the version as a string
local Version = {
    prefix = '',
    major = 0,
    minor = 0,
    patch = 0
}
Version.__index = Version

---@param version string string version
---@return Version # instance of class Version
function Version.new(version)
    local self = setmetatable({}, Version)
    local prefix, major, minor, patch, dev = string.match(version, '^(v?)(%d+)%.(%d+)%.(%d+)(%-?[%w%-%.]*)')
    self.prefix = prefix and tostring(prefix) or self.prefix
    self.major = major and tonumber(major) or self.major
    self.minor = minor and tonumber(minor) or self.minor
    self.patch = patch and tonumber(patch) or self.patch
    local pre_release, hash
    if dev then
        pre_release = string.match(dev, '^%-rc%.?(%d+)$')
    end
    if not pre_release and dev ~= nil then
        pre_release, hash = string.match(dev, '^%-(%d+)%-(%w+)$')
    end
    self.pre_release = pre_release and tonumber(pre_release) or nil
    self.hash = hash
    return self
end

---@param self Version instance of class Version
---@return string # string version
function Version.tostring(self)
    local suffix = ''
    if self.pre_release and self.hash then
        suffix = table.concat({ suffix, self.pre_release, self.hash }, '-')
    elseif self.pre_release and not self.hash then
        suffix = suffix .. '-rc' .. self.pre_release
    end
    return self.prefix .. table.concat({ self.major, self.minor, self.patch }, '.') .. suffix
end

return Version
