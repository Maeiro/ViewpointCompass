local now = 5000
local commandHandler
local replies = {}
local function player(username, factionName, x, y, onlineId)
    local faction = factionName and { getName = function() return factionName end } or nil
    return {
        faction = faction,
        getUsername = function(self) return username end,
        getX = function(self) return x end,
        getY = function(self) return y end,
        getOnlineID = function(self) return onlineId end,
    }
end

local requester = player("requester", "Alpha", 100, 100, 1)
local nearbyAlly = player("nearby", "Alpha", 250, 100, 2)
local boundaryAlly = player("boundary", "Alpha", 350, 100, 3)
local distantAlly = player("distant", "Alpha", 351, 100, 4)
local otherFaction = player("other", "Bravo", 101, 100, 5)
local rangeBoundaryAlly = player("range-boundary", "Alpha", 500, 100, 6)
local outsideRangeAlly = player("outside-range", "Alpha", 501, 100, 7)
local maximumBoundaryAlly = player("maximum-boundary", "Alpha", 1100, 100, 8)
local overMaximumAlly = player("over-maximum", "Alpha", 1101, 100, 9)
local belowMinimumAlly = player("below-minimum", "Alpha", 124, 100, 10)
local minimumBoundaryAlly = player("minimum-boundary", "Alpha", 125, 100, 11)
local outsideMinimumAlly = player("outside-minimum", "Alpha", 126, 100, 12)
local samePositionAlly = player("same-position", "Alpha", 100, 100, 13)
local onlinePlayers = {
    requester, nearbyAlly, boundaryAlly, distantAlly, otherFaction,
    rangeBoundaryAlly, outsideRangeAlly, maximumBoundaryAlly, overMaximumAlly,
    belowMinimumAlly, minimumBoundaryAlly, outsideMinimumAlly,
}
function onlinePlayers:size() return #onlinePlayers end
function onlinePlayers:get(index) return onlinePlayers[index + 1] end

getTimestampMs = function() return now end
isServer = function() return true end
Faction = { getPlayerFaction = function(candidate) return candidate.faction end }
getOnlinePlayers = function() return onlinePlayers end
sendServerCommand = function(target, module, command, args)
    replies[#replies + 1] = { target = target, module = module, command = command, args = args }
end
Events = { OnClientCommand = { Add = function(handler) commandHandler = handler end } }

require "ViewpointCompassServer"
commandHandler("another-mod", "requestFactionPlayers", requester, {})
assert(#replies == 0, "unrelated client commands ignored")
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, {})
assert(#replies == 1 and replies[1].target == requester, "response is sent only to requester")
assert(replies[1].module == "ViewpointCompass" and replies[1].command == "factionPlayers", "response command")
local peers = replies[1].args.players
assert(#peers == 5, "server filters self, other factions, and players beyond 250m")
assert(peers[1].id == 2 and peers[1].x == 250 and peers[1].y == 100
    and peers[2].id == 3 and peers[2].x == 350,
    "server includes same-faction players through the 250m boundary")
assert(peers[1].username == nil, "server sends locations without usernames")

commandHandler("ViewpointCompass", "requestFactionPlayers", requester, {})
assert(#replies == 1, "server rate limits client requests")
now = now + 750
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 400 })
local extendedPeers = replies[2].args.players
assert(#extendedPeers == 7 and extendedPeers[4].id == 6,
    "server uses the requested range and includes its boundary")
now = now + 750
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 1 })
local minimumPeers = replies[3].args.players
assert(#minimumPeers == 2 and minimumPeers[1].id == 10 and minimumPeers[2].id == 11,
    "server clamps requests to the 25m minimum")
now = now + 750
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 5000 })
local cappedPeers = replies[4].args.players
assert(#cappedPeers == 9 and cappedPeers[6].id == 8,
    "server caps client requests at 1000m")
now = now + 750
SandboxVars = { ViewpointCompass = { MaxFactionPlayerRange = 100 } }
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 500 })
local serverLimitedPeers = replies[5].args.players
assert(#serverLimitedPeers == 3 and serverLimitedPeers[1].id == 10
    and serverLimitedPeers[2].id == 11 and serverLimitedPeers[3].id == 12,
    "server enforces its maximum range even when clients request farther locations")
now = now + 750
SandboxVars = { ViewpointCompass = { AllowFactionPlayers = false } }
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 500 })
assert(#replies[6].args.players == 0, "server can disable sharing faction player locations")
now = now + 750
SandboxVars = { ViewpointCompass = { ShowFactionPlayerDistance = false } }
onlinePlayers[#onlinePlayers + 1] = samePositionAlly
commandHandler("ViewpointCompass", "requestFactionPlayers", requester, { distance = 25 })
local directionOnlyPeers = replies[7].args.players
assert(#directionOnlyPeers == 3 and directionOnlyPeers[1].id == 10
    and directionOnlyPeers[1].x == nil and directionOnlyPeers[1].y == nil
    and type(directionOnlyPeers[1].bearing) == "number",
    "server shares bearing only when exact distance is disabled")
assert(directionOnlyPeers[3].id == 13 and directionOnlyPeers[3].center == true,
    "server marks an overlapping player without transmitting their coordinates")
now = now + 750
SandboxVars = { ViewpointCompass = { MaxFactionPlayerRange = 1000 } }
local noFaction = player("no-faction", nil, 0, 0)
commandHandler("ViewpointCompass", "requestFactionPlayers", noFaction, {})
assert(#replies == 8 and #replies[8].args.players == 0, "players without a faction receive an empty list")
SandboxVars = nil

print("server_faction_players_test: PASS")
