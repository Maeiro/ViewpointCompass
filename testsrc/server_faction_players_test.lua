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
local onlinePlayers = { requester, nearbyAlly, boundaryAlly, distantAlly, otherFaction }
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
assert(#peers == 2, "server filters self, other factions, and players beyond 250m")
assert(peers[1].id == 2 and peers[1].x == 250 and peers[1].y == 100
    and peers[2].id == 3 and peers[2].x == 350,
    "server includes same-faction players through the 250m boundary")
assert(peers[1].username == nil, "server sends locations without usernames")

commandHandler("ViewpointCompass", "requestFactionPlayers", requester, {})
assert(#replies == 1, "server rate limits client requests")
now = now + 750
local noFaction = player("no-faction", nil, 0, 0)
commandHandler("ViewpointCompass", "requestFactionPlayers", noFaction, {})
assert(#replies == 2 and #replies[2].args.players == 0, "players without a faction receive an empty list")

print("server_faction_players_test: PASS")
