local MOD_ID = "ViewpointCompass"
local MAX_DISTANCE = 250
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
    local faction = factionOf(player)
    local name = factionName(faction)
    if name then
        local senderX, senderY = player:getX(), player:getY()
        local onlinePlayers = getOnlinePlayers()
        for index = 0, onlinePlayers:size() - 1 do
            local other = onlinePlayers:get(index)
            if other and other:getUsername() ~= username and factionName(factionOf(other)) == name then
                local x, y = other:getX(), other:getY()
                local dx, dy = x - senderX, y - senderY
                if dx * dx + dy * dy <= MAX_DISTANCE * MAX_DISTANCE then
                    peers[#peers + 1] = { id = other:getOnlineID(), x = x, y = y }
                end
            end
        end
    end

    sendServerCommand(player, MOD_ID, "factionPlayers", { players = peers })
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(onClientCommand)
end
