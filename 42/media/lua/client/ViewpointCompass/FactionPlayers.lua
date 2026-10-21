local FactionPlayers = ViewpointCompassFactionPlayers or {}
if FactionPlayers.initialized then return end
local ServerPolicy = ViewpointCompassServerPolicy or require "ViewpointCompass/ServerPolicy"

local MOD_ID = "ViewpointCompass"
local DEFAULT_DISTANCE = 250
local REQUEST_INTERVAL_MS = 1000
local RESPONSE_TIMEOUT_MS = 3500
local SMOOTHING_DURATION_MS = 1000
local ROW_HEIGHT = 42
local players = {}
local playersById = {}
local lastRequestAt
local lastRequestedRange
local lastRequestedDistanceVisibility
local lastResponseAt
local enabled = true

local function detectionRange(distance)
    if type(distance) ~= "number" then distance = DEFAULT_DISTANCE end
    return ServerPolicy.limitFactionPlayerRange(distance)
end

local function timestamp()
    return type(getTimestampMs) == "function" and getTimestampMs() or 0
end

local function updateInterpolatedPosition(player, now)
    local progress = math.max(0, math.min(1, (now - player.startedAt) / SMOOTHING_DURATION_MS))
    progress = progress * progress * (3 - 2 * progress)
    if player.targetBearing ~= nil then
        local difference = (player.targetBearing - player.startBearing + 540) % 360 - 180
        player.bearing = (player.startBearing + difference * progress) % 360
    else
        player.x = player.startX + (player.targetX - player.startX) * progress
        player.y = player.startY + (player.targetY - player.startY) * progress
    end
end

local function isMultiplayerClient()
    for _, name in ipairs({ "isMultiplayer", "isClient" }) do
        local check = _G[name]
        if type(check) == "function" then
            local ok, value = pcall(check)
            if ok and value == true then return true end
        end
    end
    return false
end

local function onServerCommand(module, command, args)
    if module ~= MOD_ID or command ~= "factionPlayers" or not enabled then return end
    local updated = {}
    local updatedById = {}
    local incoming = type(args) == "table" and args.players
    local now = timestamp()
    if type(incoming) == "table" then
        for _, player in pairs(incoming) do
            local hasPosition = type(player) == "table"
                and type(player.x) == "number" and type(player.y) == "number"
            local hasBearing = type(player) == "table" and type(player.bearing) == "number"
                and player.bearing == player.bearing
                and player.bearing ~= math.huge and player.bearing ~= -math.huge
            if type(player) == "table" and type(player.id) == "number" and (hasPosition or hasBearing) then
                local key = tostring(player.id)
                local previous = playersById[key]
                if hasBearing then
                    local targetBearing = player.bearing % 360
                    local startBearing = targetBearing
                    if previous and previous.bearing then
                        updateInterpolatedPosition(previous, now)
                        startBearing = previous.bearing
                    end
                    local tracked = {
                        id = player.id,
                        bearing = startBearing,
                        center = player.center == true,
                        startBearing = startBearing,
                        targetBearing = targetBearing,
                        startedAt = now,
                    }
                    updated[#updated + 1] = tracked
                    updatedById[key] = tracked
                else
                    local startX, startY = player.x, player.y
                    if previous and previous.x and previous.y then
                        updateInterpolatedPosition(previous, now)
                        startX, startY = previous.x, previous.y
                    end
                    local tracked = {
                        id = player.id,
                        x = startX,
                        y = startY,
                        startX = startX,
                        startY = startY,
                        targetX = player.x,
                        targetY = player.y,
                        startedAt = now,
                    }
                    updated[#updated + 1] = tracked
                    updatedById[key] = tracked
                end
            end
        end
    end
    players, playersById = updated, updatedById
    lastResponseAt = now
end

function FactionPlayers.update(showPlayers, maxDistance)
    enabled = showPlayers == true and ServerPolicy.getBoolean("AllowFactionPlayers")
    if not enabled then
        players, playersById = {}, {}
        lastResponseAt = nil
        return
    end
    if not isMultiplayerClient() or type(sendClientCommand) ~= "function"
            or type(getSpecificPlayer) ~= "function" then
        return
    end

    local now = timestamp()
    local range = detectionRange(maxDistance)
    local showDistance = ServerPolicy.getBoolean("ShowFactionPlayerDistance")
    if range ~= lastRequestedRange or showDistance ~= lastRequestedDistanceVisibility then
        players, playersById = {}, {}
        lastResponseAt = nil
        lastRequestAt = nil
        lastRequestedRange = range
        lastRequestedDistanceVisibility = showDistance
    end
    if lastRequestAt and now - lastRequestAt < REQUEST_INTERVAL_MS then return end
    local player = getSpecificPlayer(0)
    if not player then return end

    lastRequestAt = now
    pcall(sendClientCommand, player, MOD_ID, "requestFactionPlayers", {
        distance = range,
    })
end

function FactionPlayers.getPlayers()
    if not enabled or not lastResponseAt or timestamp() - lastResponseAt > RESPONSE_TIMEOUT_MS then
        return {}
    end
    local now = timestamp()
    for _, player in ipairs(players) do
        updateInterpolatedPosition(player, now)
    end
    return players
end

function FactionPlayers.hasNearby(player, peers, maxDistance)
    if not player then return false end
    local maxDistanceSquared = detectionRange(maxDistance) ^ 2
    local playerX, playerY
    local ok = pcall(function() playerX, playerY = player:getX(), player:getY() end)
    if not ok or type(playerX) ~= "number" or type(playerY) ~= "number" then return false end

    for _, peer in ipairs(peers or {}) do
        if type(peer.bearing) == "number" then return true end
        local dx, dy = peer.x - playerX, peer.y - playerY
        if dx * dx + dy * dy <= maxDistanceSquared then return true end
    end
    return false
end

function FactionPlayers.layout(mapPosition, hasMapMarkers, playerPosition, hasPlayers, compassHeight, scale)
    scale = scale or 1
    local height = compassHeight or ROW_HEIGHT * scale
    local rowHeight = ROW_HEIGHT * scale
    if mapPosition ~= 1 and mapPosition ~= 2 and mapPosition ~= 3 then mapPosition = 2 end
    if playerPosition ~= 1 and playerPosition ~= 2 and playerPosition ~= 3 then playerPosition = 2 end

    local mapAbove = hasMapMarkers and mapPosition == 1
    local mapBelow = hasMapMarkers and mapPosition == 3
    local playerAbove = hasPlayers and playerPosition == 1
    local playerBelow = hasPlayers and playerPosition == 3
    local topHeight = (mapAbove and height or 0) + (playerAbove and rowHeight or 0)
    local bottomHeight = (mapBelow and height or 0) + (playerBelow and rowHeight or 0)
    local playerY = topHeight

    if playerAbove then
        playerY = mapAbove and height or 0
    elseif playerBelow then
        playerY = topHeight + height + (mapBelow and height or 0)
    end

    local mapY = topHeight
    if mapAbove then
        mapY = 0
    elseif mapBelow then
        mapY = topHeight + height
    end

    return {
        rulerY = topHeight,
        height = topHeight + height + bottomHeight,
        mapY = mapY,
        mapInside = mapPosition == 2,
        playerY = playerY,
        playerInside = playerPosition == 2,
    }
end

function FactionPlayers.project(player, peers, heading, width, pixelsPerDegree, scale, maxDistance, showDistance)
    if not player or type(heading) ~= "number" or type(width) ~= "number"
            or type(pixelsPerDegree) ~= "number" then return {} end

    local playerX, playerY
    local ok = pcall(function()
        playerX, playerY = player:getX(), player:getY()
    end)
    if not ok or type(playerX) ~= "number" or type(playerY) ~= "number" then return {} end

    scale = scale or 1
    local maxDistanceSquared = detectionRange(maxDistance) ^ 2
    local points = {}
    for _, peer in ipairs(peers or {}) do
        local distance, bearing, dx, dy
        if type(peer.bearing) == "number" then
            bearing = peer.bearing % 360
        elseif type(peer.x) == "number" and type(peer.y) == "number" then
            dx, dy = peer.x - playerX, peer.y - playerY
            distance = math.sqrt(dx * dx + dy * dy)
            bearing = (math.deg(math.atan2(dy, dx)) + 90) % 360
        end
        if bearing and (distance == nil or distance * distance <= maxDistanceSquared) then
            local delta = peer.center and 0 or (bearing - heading + 540) % 360 - 180
            if dx and dx == 0 and dy == 0 then delta = 0 end
            local x = width / 2 + delta * pixelsPerDegree
            if x >= 0 and x <= width then
                local visibleDistance = distance
                if showDistance == false then visibleDistance = nil end
                points[#points + 1] = {
                    x = math.max(10 * scale, math.min(width - 10 * scale, x)),
                    distance = visibleDistance,
                    count = 0,
                }
            end
        end
    end

    table.sort(points, function(a, b) return a.x < b.x end)
    local groups = {}
    for _, point in ipairs(points) do
        local group = groups[#groups]
        if group and point.x - group.right < 24 * scale then
            group.right = point.x
            group.count = group.count + 1
            if point.distance and (not group.distance or point.distance < group.distance) then
                group.x, group.distance = point.x, point.distance
            end
        else
            point.right = point.x
            groups[#groups + 1] = point
        end
    end
    return groups
end

FactionPlayers.MAX_DISTANCE = MAX_DISTANCE
FactionPlayers.ROW_HEIGHT = ROW_HEIGHT
FactionPlayers.initialized = true
ViewpointCompassFactionPlayers = FactionPlayers

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
end

return FactionPlayers
