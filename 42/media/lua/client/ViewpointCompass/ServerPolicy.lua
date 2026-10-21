local ServerPolicy = ViewpointCompassServerPolicy or {}
if ServerPolicy.initialized then return ServerPolicy end

local DEFAULTS = {
    RequireCompassItem = false,
    AllowMapWaypoints = true,
    AllowFactionPlayers = true,
    MaxFactionPlayerRange = 1000,
    ShowFactionPlayerDistance = true,
}
local MIN_RANGE = 25
local MAX_RANGE = 1000

local function options()
    local sandbox = type(SandboxVars) == "table" and SandboxVars.ViewpointCompass
    return type(sandbox) == "table" and sandbox or nil
end

function ServerPolicy.getBoolean(name)
    local sandbox = options()
    local value = sandbox and sandbox[name]
    if type(value) == "boolean" then return value end
    return DEFAULTS[name] == true
end

function ServerPolicy.getMaxFactionPlayerRange()
    local sandbox = options()
    local value = sandbox and sandbox.MaxFactionPlayerRange
    if type(value) ~= "number" or value ~= value then value = DEFAULTS.MaxFactionPlayerRange end
    return math.max(MIN_RANGE, math.min(MAX_RANGE, math.floor(value)))
end

function ServerPolicy.limitFactionPlayerRange(distance)
    if type(distance) ~= "number" then distance = 250 end
    distance = math.max(MIN_RANGE, math.min(MAX_RANGE, distance))
    return math.min(distance, ServerPolicy.getMaxFactionPlayerRange())
end

ServerPolicy.initialized = true
ViewpointCompassServerPolicy = ServerPolicy

return ServerPolicy
