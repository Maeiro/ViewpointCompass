require "PZAPI/ModOptions"
require "ISUI/ISUIElement"

local MOD_ID = "ViewpointCompass"
local WIDTH = 520
local HEIGHT = 42
local PIXELS_PER_DEGREE = 6
local HALF_RANGE = WIDTH / (2 * PIXELS_PER_DEGREE)
local uiByPlayer = {}

local options
if PZAPI and PZAPI.ModOptions then
    options = PZAPI.ModOptions:create(MOD_ID, "Viewpoint Compass")
    options:addTickBox("ShowCompass", "Show directional compass", true)
    options:addTickBox(
        "RequireCompassItem",
        "Require a Compass item to show the compass",
        false,
        "When enabled, you must carry the vanilla Compass item in your inventory or a carried bag."
    )
end

local function optionValue(name, fallback)
    if not options or not options.getOption then return fallback end
    local ok, option = pcall(function() return options:getOption(name) end)
    if not ok or not option or not option.getValue then return fallback end
    local valueOk, value = pcall(function() return option:getValue() end)
    if not valueOk or value == nil then return fallback end
    return value
end

local function hasCompassItem(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    local ok, hasCompass = pcall(function()
        local inventory = player:getInventory()
        return inventory and inventory:contains("Base.CompassDirectional", true)
    end)
    return ok and hasCompass == true
end

local function cameraHeading()
    if not ViewpointCompass or not ViewpointCompass.getHeading then return nil end
    local ok, heading = pcall(ViewpointCompass.getHeading)
    if not ok or type(heading) ~= "number" or heading < 0 or heading >= 360 then
        return nil
    end
    return heading
end

local function shortestAngle(angle)
    return (angle + 540) % 360 - 180
end

local function cardinalDirection(heading)
    local directions = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
    local index = math.floor((heading + 22.5) / 45) % #directions + 1
    return directions[index]
end

local function playerScreenBounds(playerNum)
    local ok, left, top, width = pcall(function()
        return getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum), getPlayerScreenWidth(playerNum)
    end)
    if not ok then return nil end
    return left, top, width
end

local ViewpointCompassUI = ISUIElement:derive("ViewpointCompassUI")

function ViewpointCompassUI:new(playerNum)
    local o = ISUIElement.new(self, 0, 0, WIDTH, HEIGHT)
    o.playerNum = playerNum
    o.heading = 0
    o:initialise()
    o:instantiate()
    o:setRenderThisPlayerOnly(playerNum)
    o:setFollowGameWorld(false)
    o:addToUIManager()
    o:setVisible(false)
    return o
end

function ViewpointCompassUI:render()
    local width = self:getWidth()
    local centerX = width / 2
    local heading = self.heading

    self:drawRect(0, 29, width, 1, 0.28, 0.82, 0.88, 0.91)

    for bearing = 0, 355, 5 do
        local delta = shortestAngle(bearing - heading)
        if math.abs(delta) <= HALF_RANGE then
            local x = centerX + delta * PIXELS_PER_DEGREE
            local major = bearing % 15 == 0
            local tickHeight = major and 12 or 6
            self:drawRect(x, 29 - tickHeight, 1, tickHeight, major and 0.78 or 0.48,
                0.85, 0.9, 0.92)

            if major and math.abs(delta) > 5 then
                self:drawTextCentre(string.format("%03d", bearing), x, 3,
                    0.76, 0.82, 0.85, 0.92, UIFont.Small)
            end
        end
    end

    local centerWidth = 58
    self:drawRect(centerX - centerWidth / 2, 1, centerWidth, 23,
        0.72, 0.16, 0.19, 0.22)
    self:drawRectBorder(centerX - centerWidth / 2, 1, centerWidth, 23,
        0.58, 0.72, 0.78, 0.81)
    self:drawTextCentre(string.format("%03d %s", math.floor(heading + 0.5) % 360,
        cardinalDirection(heading)), centerX, 4, 0.96, 0.94, 0.94, 0.94, UIFont.Small)
end

local function ensureCompass(playerNum)
    if uiByPlayer[playerNum] then return uiByPlayer[playerNum] end
    local ok, ui = pcall(function() return ViewpointCompassUI:new(playerNum) end)
    if not ok then return nil end
    uiByPlayer[playerNum] = ui
    return ui
end

local function updateCompasses()
    local enabled = optionValue("ShowCompass", true)
    local requireCompassItem = optionValue("RequireCompassItem", false)
    local heading = enabled and cameraHeading() or nil
    for playerNum, ui in pairs(uiByPlayer) do
        local visible = heading ~= nil
            and (not requireCompassItem or hasCompassItem(playerNum))
        if ui:getIsVisible() ~= visible then
            ui:setVisible(visible)
        end
        if visible then
            local left, top, width = playerScreenBounds(playerNum)
            if left and top and width then
                ui:setX(left + (width - ui:getWidth()) / 2)
                ui:setY(top + 18)
            end
            ui.heading = heading
        end
    end
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(playerNum)
        ensureCompass(playerNum)
    end)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        local playerCount = getNumActivePlayers and getNumActivePlayers() or 1
        for playerNum = 0, playerCount - 1 do
            ensureCompass(playerNum)
        end
        updateCompasses()
    end)
end

if Events and Events.OnPreUIDraw then
    Events.OnPreUIDraw.Add(updateCompasses)
end
