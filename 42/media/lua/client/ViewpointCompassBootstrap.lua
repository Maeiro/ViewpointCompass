local MOD_ID = "ViewpointCompass"
local CLIENT_LUA_ROOT = "media/lua/client/"

-- Repeated ZombieBuddy exposure can remove aliases while keeping the package tables.
local bridges = maeiro and maeiro.viewpointcompass
if bridges then
    ViewpointCompassClient = ViewpointCompassClient or bridges.ClientLuaBootstrap
    ViewpointCompass = ViewpointCompass or bridges.ViewpointCompassBridge
    ViewpointCompassMap = ViewpointCompassMap or bridges.MapMarkerBridge
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

local function runModLua(relativePath)
    if type(getModFileReader) ~= "function" then
        return false, "getModFileReader is unavailable"
    end
    if type(loadstring) ~= "function" then
        return false, "loadstring is unavailable"
    end

    local openOk, reader = pcall(getModFileReader, MOD_ID, CLIENT_LUA_ROOT .. relativePath, false)
    if not openOk or not reader then
        return false, "could not open " .. relativePath .. ": " .. tostring(reader)
    end

    local readOk, source = pcall(function()
        local lines = {}
        while true do
            local line = reader:readLine()
            if line == nil then break end
            lines[#lines + 1] = line
        end
        reader:close()
        return table.concat(lines, "\n")
    end)
    if not readOk then
        pcall(function() reader:close() end)
        return false, source
    end

    local chunk, compileError = loadstring(source)
    if not chunk then return false, compileError end

    local ok, result = pcall(chunk)
    if not ok then return false, result end
    return true, result
end

if not ViewpointCompassClient then
    return
end

if ViewpointCompassLuaLoaded then
    ViewpointCompassClient.markLuaLoaded()
    return
end

local multiplayer = isMultiplayerClient()

if multiplayer then
    ViewpointCompassLuaLoaded = nil
    ViewpointCompassMapIntegrationLoaded = nil

    for _, relativePath in ipairs({
        "ViewpointCompass/Markers.lua",
        "ViewpointCompass/MarkerWindow.lua",
        "ViewpointCompass/ServerPolicy.lua",
        "ViewpointCompass/MapIntegration.lua",
        "ViewpointCompass/FactionPlayers.lua",
        "ViewpointCompass.lua",
    }) do
        local ok = runModLua(relativePath)
        if not ok then
            return
        end
    end

    if not ViewpointCompassLuaLoaded then
        return
    end
else
    if not ViewpointCompassLuaLoaded then
        local ok = pcall(require, "ViewpointCompass")
        if not ok or not ViewpointCompassLuaLoaded then
            return
        end
    end
end

ViewpointCompassClient.markLuaLoaded()
