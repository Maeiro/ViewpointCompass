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
assert(#sentRequests == 1 and sentRequests[1].command == "requestFactionPlayers", "client requests server snapshot")
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

local north = FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 0, 520, 6)
assert(#north == 1 and math.abs(north[1].x - 260) < 0.001, "north bearing projection")
local wrapped = FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 359, 520, 6)
assert(#wrapped == 1 and math.abs(wrapped[1].x - 266) < 0.001, "bearing wraps at north")
assert(#FactionPlayers.project(localPlayer, { { x = 0, y = -50 } }, 180, 520, 6) == 0,
    "players outside the visible ribbon are hidden")
assert(#FactionPlayers.project(localPlayer, { { x = 0, y = -251 } }, 0, 520, 6) == 0,
    "players beyond the server range are hidden")
local grouped = FactionPlayers.project(localPlayer, { { x = 0, y = -50 }, { x = 0, y = -20 } }, 0, 520, 6)
assert(#grouped == 1 and grouped[1].distance == 20 and grouped[1].count == 1,
    "overlapping players show nearest distance and additional count")

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

print("faction_players_test: PASS")
