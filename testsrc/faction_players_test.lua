local now = 1000
local commandHandler
local sentRequests = {}
local localPlayer = {
    getX = function() return 0 end,
    getY = function() return 0 end,
}

getTimestampMs = function() return now end
isMultiplayer = function() return true end
isClient = function() return true end
getSpecificPlayer = function(playerNum) assert(playerNum == 0); return localPlayer end
sendClientCommand = function(player, module, command, args)
    sentRequests[#sentRequests + 1] = { player = player, module = module, command = command, args = args }
end
Events = { OnServerCommand = { Add = function(handler) commandHandler = handler end } }

local FactionPlayers = require "ViewpointCompass/FactionPlayers"
FactionPlayers.update(true)
assert(#sentRequests == 1 and sentRequests[1].command == "requestFactionPlayers"
    and sentRequests[1].args.distance == 250, "client requests the default detection range")
FactionPlayers.update(true)
assert(#sentRequests == 1, "requests are rate limited")

commandHandler("another-mod", "factionPlayers", { players = { { x = 0, y = -20 } } })
assert(#FactionPlayers.getPlayers() == 0, "unrelated server command ignored")
commandHandler("ViewpointCompass", "factionPlayers", {
    players = {
        { id = 11, x = 0, y = -50 },
        { id = 12, x = 0, y = -20 },
        { id = 13, x = "bad", y = 10 },
        false,
    },
})
local peers = FactionPlayers.getPlayers()
assert(#peers == 2, "invalid coordinates are discarded")
assert(FactionPlayers.hasNearby(localPlayer, peers), "nearby faction member reserves the icon row")
assert(not FactionPlayers.hasNearby(localPlayer, { { x = 0, y = -50 } }, 25),
    "configured range filters nearby row")

local north = FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 0, 520, 6)
assert(#north == 1 and math.abs(north[1].x - 260) < 0.001, "north bearing projection")
local wrapped = FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 359, 520, 6)
assert(#wrapped == 1 and math.abs(wrapped[1].x - 266) < 0.001, "bearing wraps at north")
assert(#FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 180, 520, 6) == 0,
    "players outside the visible ribbon are hidden")
assert(#FactionPlayers.project(localPlayer, { { x = 0, y = -251 } }, 0, 520, 6) == 0,
    "players beyond the server range are hidden")
assert(#FactionPlayers.project(localPlayer, { { x = 0, y = -251 } }, 0, 520, 6, 1, 300) == 1,
    "configured range controls visible allies")
local grouped = FactionPlayers.project(localPlayer, { { x = 0, y = -50 }, { x = 0, y = -20 } }, 0, 520, 6)
assert(#grouped == 1 and grouped[1].distance == 20 and grouped[1].count == 1,
    "overlapping players show nearest distance and additional count")
local directionOnly = FactionPlayers.project(localPlayer, { { bearing = 359 } }, 359, 520, 6, 1, 300, false)
assert(#directionOnly == 1 and directionOnly[1].distance == nil,
    "bearing-only faction data displays direction without exposing a distance")
local samePosition = FactionPlayers.project(localPlayer, { { bearing = 0, center = true } }, 359, 520, 6)
assert(#samePosition == 1 and math.abs(samePosition[1].x - 260) < 0.001,
    "a faction member sharing the player's position is centered without coordinates")
assert(FactionPlayers.hasNearby(localPlayer, { { bearing = 359 } }, 250),
    "server-filtered bearing-only data reserves the faction marker row")

local middleLayout = FactionPlayers.layout(2, false, 2, true, 42)
assert(middleLayout.height == 42 and middleLayout.rulerY == 0
    and middleLayout.playerInside and middleLayout.playerY == 0, "middle placement is compact")
local topLayout = FactionPlayers.layout(1, true, 1, true, 42)
assert(topLayout.height == 126 and topLayout.rulerY == 84
    and topLayout.mapY == 0 and topLayout.playerY == 42, "top lanes stack without overlap")
local bottomLayout = FactionPlayers.layout(3, true, 3, true, 42)
assert(bottomLayout.height == 126 and bottomLayout.rulerY == 0
    and bottomLayout.mapY == 42 and bottomLayout.playerY == 84, "bottom lanes stack without overlap")
local mapAbovePlayerMiddle = FactionPlayers.layout(1, true, 2, true, 42)
assert(mapAbovePlayerMiddle.rulerY == 42 and mapAbovePlayerMiddle.playerY == 42,
    "middle player marker stays in the compass when map markers are above")
local noAllyLayout = FactionPlayers.layout(1, true, 3, false, 42)
assert(noAllyLayout.height == 84, "hidden ally markers reserve no space")
local scaledLayout = FactionPlayers.layout(1, true, 3, true, 84, 2)
assert(scaledLayout.height == 252 and scaledLayout.mapY == 0 and scaledLayout.playerY == 168,
    "map and faction rows scale together")
local scaledNorth = FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 359, 1040, 12, 2)
assert(#scaledNorth == 1 and math.abs(scaledNorth[1].x - 532) < 0.001,
    "faction marker positions scale with the compass")

commandHandler("ViewpointCompass", "factionPlayers", "invalid payload")
assert(#FactionPlayers.getPlayers() == 0, "malformed server payload safely clears snapshot")
FactionPlayers.update(false)
assert(#FactionPlayers.getPlayers() == 0, "disabled option clears markers")
now = now + 1000
FactionPlayers.update(true)
assert(#sentRequests == 2, "re-enabled option requests a fresh snapshot")
commandHandler("ViewpointCompass", "factionPlayers", { players = { { id = 11, x = 0, y = 30 } } })
assert(#FactionPlayers.getPlayers() == 1, "new response restores markers")
now = now + 1000
commandHandler("ViewpointCompass", "factionPlayers", { players = { { id = 11, x = 0, y = 130 } } })
assert(FactionPlayers.getPlayers()[1].y == 30, "updated location starts from the last reported point")
now = now + 250
assert(math.abs(FactionPlayers.getPlayers()[1].y - 45.625) < 0.001,
    "smooth easing starts with a gentle movement")
now = now + 250
assert(math.abs(FactionPlayers.getPlayers()[1].y - 80) < 0.001, "location interpolates smoothly between updates")
now = now + 250
assert(math.abs(FactionPlayers.getPlayers()[1].y - 114.375) < 0.001,
    "smooth easing decelerates near the updated location")
now = now + 250
assert(FactionPlayers.getPlayers()[1].y == 130, "interpolation reaches the latest server position")
FactionPlayers.update(true, 500)
assert(#sentRequests == 3 and sentRequests[3].args.distance == 500,
    "client sends the configured range to the server")
now = now + 1000
FactionPlayers.update(true, 0)
assert(#sentRequests == 4 and sentRequests[4].args.distance == 25,
    "client clamps the requested range to its minimum")
now = now + 1000
FactionPlayers.update(true, 5000)
assert(#sentRequests == 5 and sentRequests[5].args.distance == 1000,
    "client clamps the requested range to its maximum")
SandboxVars = { ViewpointCompass = { MaxFactionPlayerRange = 100 } }
now = now + 1000
FactionPlayers.update(true, 500)
assert(#sentRequests == 6 and sentRequests[6].args.distance == 100,
    "client respects the server's maximum faction range")
SandboxVars = { ViewpointCompass = {
    RequireCompassItem = true,
    AllowMapWaypoints = false,
    AllowFactionPlayers = false,
    ShowFactionPlayerDistance = false,
} }
local ServerPolicy = require "ViewpointCompass/ServerPolicy"
assert(ServerPolicy.getBoolean("RequireCompassItem")
    and not ServerPolicy.getBoolean("AllowMapWaypoints")
    and not ServerPolicy.getBoolean("ShowFactionPlayerDistance"),
    "client reads the server's compass, waypoint, and distance policies")
FactionPlayers.update(true, 500)
assert(#FactionPlayers.getPlayers() == 0, "server policy disables faction markers")
SandboxVars = nil

print("faction_players_test: PASS")
