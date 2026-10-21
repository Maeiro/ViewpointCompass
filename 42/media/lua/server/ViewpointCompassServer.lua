local MOD_ID = "ViewpointCompass"
local DEFAULT_DISTANCE = 250
local MIN_DISTANCE = 25
local MAX_DISTANCE = 1000
local REQUEST_INTERVAL_MS = 750
local lastRequestByUsername = {}

local function factionOf(player)
    if not Faction or type(Faction.getPlayerFaction) ~= "function" then return nil end
    local ok, faction = pcall(function() return Faction.getPlayerFaction(player) end)
    return ok and faction or nil
end

local function factionName(faction)
    if not faction then return nil end
    local ok, name = pcall(function() return faction:getName() end)
    return ok and type(name) == "string" and name or nil
end

local function sandboxSettings()
    local sandbox = type(SandboxVars) == "table" and SandboxVars.ViewpointCompass
    return type(sandbox) == "table" and sandbox or nil
end

local function booleanSetting(name, default)
    local settings = sandboxSettings()
    local value = settings and settings[name]
    if type(value) == "boolean" then return value end
    return default
end

local function maximumFactionPlayerRange()
    local settings = sandboxSettings()
    local range = settings and settings.MaxFactionPlayerRange
    if type(range) ~= "number" or range ~= range then range = MAX_DISTANCE end
    return math.max(MIN_DISTANCE, math.min(MAX_DISTANCE, math.floor(range)))
end

local function requestedDistance(args)
    local distance = type(args) == "table" and args.distance or nil
    if type(distance) ~= "number" or distance ~= distance then return DEFAULT_DISTANCE end
    distance = math.max(MIN_DISTANCE, math.min(MAX_DISTANCE, distance))
    return math.min(distance, maximumFactionPlayerRange())
end

local function bearing(dx, dy)
    return (math.deg(math.atan2(dy, dx)) + 90) % 360
end

local function onClientCommand(module, command, player, args)
    if type(isServer) ~= "function" or not isServer()
            or module ~= MOD_ID or command ~= "requestFactionPlayers" or not player then return end
    if type(getTimestampMs) ~= "function" or type(getOnlinePlayers) ~= "function"
            or type(sendServerCommand) ~= "function" then return end

    local ok, username = pcall(function() return player:getUsername() end)
    if not ok or type(username) ~= "string" or username == "" then return end

    local now = getTimestampMs()
    for previousUsername, lastRequest in pairs(lastRequestByUsername) do
        if now - lastRequest > 10000 then lastRequestByUsername[previousUsername] = nil end
    end
    local previousRequest = lastRequestByUsername[username]
    if previousRequest and now - previousRequest < REQUEST_INTERVAL_MS then return end
    lastRequestByUsername[username] = now

    local peers = {}
    local maxDistance = requestedDistance(args)
    local faction = factionOf(player)
    local name = factionName(faction)
    local allowFactionPlayers = booleanSetting("AllowFactionPlayers", true)
    local showDistance = booleanSetting("ShowFactionPlayerDistance", true)
    if allowFactionPlayers and name then
        local senderX, senderY = player:getX(), player:getY()
        local onlinePlayers = getOnlinePlayers()
        for index = 0, onlinePlayers:size() - 1 do
            local other = onlinePlayers:get(index)
            if other and other:getUsername() ~= username and factionName(factionOf(other)) == name then
                local x, y = other:getX(), other:getY()
                local dx, dy = x - senderX, y - senderY
                if dx * dx + dy * dy <= maxDistance * maxDistance then
                    local peer = { id = other:getOnlineID() }
                    if showDistance then
                        peer.x, peer.y = x, y
                    else
                        peer.center = dx == 0 and dy == 0
                        peer.bearing = peer.center and 0 or bearing(dx, dy)
                    end
                    peers[#peers + 1] = peer
                end
            end
        end
    end

    sendServerCommand(player, MOD_ID, "factionPlayers", { players = peers })
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(onClientCommand)
end
