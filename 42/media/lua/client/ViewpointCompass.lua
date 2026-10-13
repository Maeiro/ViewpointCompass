require "PZAPI/ModOptions"
require "ISUI/ISUIElement"
local Markers = require "ViewpointCompass/Markers"
require "ViewpointCompass/MapIntegration"

local MOD_ID = "ViewpointCompass"
local DEFAULT_WIDTH = 520
local MIN_WIDTH = 360
local MAX_WIDTH = 1000
local HEIGHT = 42
local PIXELS_PER_DEGREE = 6
local DEFAULT_LABEL_COLOR = { r = 222 / 255, g = 178 / 255, b = 110 / 255, a = 1 }
local LANGUAGE_NAMES = {
    "English",
    "Portuguese (Brazil)",
    "Chinese (Simplified)",
    "Russian",
    "Spanish",
    "French",
    "German",
    "Japanese",
}
local DIRECTIONS_BY_LANGUAGE = {
    { "N", "NE", "E", "SE", "S", "SW", "W", "NW" },
    { "N", "NE", "L", "SE", "S", "SO", "O", "NO" },
    { "Bei", "Dongbei", "Dong", "Dongnan", "Nan", "Xinan", "Xi", "Xibei" },
    {
        "UI_ViewpointCompass_RU_N", "UI_ViewpointCompass_RU_NE",
        "UI_ViewpointCompass_RU_E", "UI_ViewpointCompass_RU_SE",
        "UI_ViewpointCompass_RU_S", "UI_ViewpointCompass_RU_SW",
        "UI_ViewpointCompass_RU_W", "UI_ViewpointCompass_RU_NW",
    },
    { "N", "NE", "E", "SE", "S", "SO", "O", "NO" },
    { "N", "NE", "E", "SE", "S", "SO", "O", "NO" },
    { "N", "NO", "O", "SO", "S", "SW", "W", "NW" },
    { "Kita", "Hokuto", "Higashi", "Nanto", "Minami", "Nansei", "Nishi", "Hokusei" },
}
local NATIVE_DIRECTIONS_BY_LANGUAGE = {
    [3] = {
        CN = {
            "UI_ViewpointCompass_CN_N", "UI_ViewpointCompass_CN_NE",
            "UI_ViewpointCompass_CN_E", "UI_ViewpointCompass_CN_SE",
            "UI_ViewpointCompass_CN_S", "UI_ViewpointCompass_CN_SW",
            "UI_ViewpointCompass_CN_W", "UI_ViewpointCompass_CN_NW",
        },
        CH = {
            "UI_ViewpointCompass_CH_N", "UI_ViewpointCompass_CH_NE",
            "UI_ViewpointCompass_CH_E", "UI_ViewpointCompass_CH_SE",
            "UI_ViewpointCompass_CH_S", "UI_ViewpointCompass_CH_SW",
            "UI_ViewpointCompass_CH_W", "UI_ViewpointCompass_CH_NW",
        },
    },
    [8] = {
        JP = {
            "UI_ViewpointCompass_JP_N", "UI_ViewpointCompass_JP_NE",
            "UI_ViewpointCompass_JP_E", "UI_ViewpointCompass_JP_SE",
            "UI_ViewpointCompass_JP_S", "UI_ViewpointCompass_JP_SW",
            "UI_ViewpointCompass_JP_W", "UI_ViewpointCompass_JP_NW",
        },
    },
}
local LATIN_FALLBACK_DIRECTIONS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local uiByPlayer = {}

local options
if PZAPI and PZAPI.ModOptions then
    options = PZAPI.ModOptions:create(MOD_ID, "Viewpoint Compass")
    options:addTickBox("ShowCompass", "Show directional compass", true)
    options:addTickBox("ShowMapMarkers", Markers.text("Show"), true)
    options:addTickBox("MapMarkerBackground", Markers.text("Background"), false)
    local markerPosition = options:addComboBox("MapMarkerPosition", Markers.text("Position"))
    for index, key in ipairs({ "Above", "Inside", "Below" }) do
        markerPosition:addItem(Markers.text(key), index == 2)
    end
    options:addTickBox(
        "RequireCompassItem",
        "Require a Compass item to show the compass",
        false,
        "When enabled, you must carry the vanilla Compass item in your inventory or a carried bag."
    )
    options:addSlider("CompassWidth", "Compass width (pixels)", MIN_WIDTH, MAX_WIDTH, 20, DEFAULT_WIDTH)
    options:addColorPicker(
        "CompassLabelColor",
        "Compass direction label color",
        DEFAULT_LABEL_COLOR.r,
        DEFAULT_LABEL_COLOR.g,
        DEFAULT_LABEL_COLOR.b,
        DEFAULT_LABEL_COLOR.a
    )
    local languageOption = options:addComboBox("CompassLanguage", "Compass direction language")
    for index, language in ipairs(LANGUAGE_NAMES) do
        languageOption:addItem(language, index == 1)
    end
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

local function compassWidth()
    local width = optionValue("CompassWidth", DEFAULT_WIDTH)
    if type(width) ~= "number" then return DEFAULT_WIDTH end
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, width))
end

local function compassLanguage()
    local language = optionValue("CompassLanguage", 1)
    if type(language) ~= "number" or DIRECTIONS_BY_LANGUAGE[language] == nil then
        return 1
    end
    return language
end

local function compassLabelColor()
    local color = optionValue("CompassLabelColor", DEFAULT_LABEL_COLOR)
    if type(color) ~= "table" or type(color.r) ~= "number"
        or type(color.g) ~= "number" or type(color.b) ~= "number" then
        return DEFAULT_LABEL_COLOR
    end
    return {
        r = math.max(0, math.min(1, color.r)),
        g = math.max(0, math.min(1, color.g)),
        b = math.max(0, math.min(1, color.b)),
        a = type(color.a) == "number" and math.max(0, math.min(1, color.a)) or 1,
    }
end

local function directionAtBearing(bearing, language, activeLanguageCode)
    local directions = DIRECTIONS_BY_LANGUAGE[language] or DIRECTIONS_BY_LANGUAGE[1]
    local index = math.floor((bearing + 22.5) / 45) % #directions + 1
    local nativeByGameLanguage = NATIVE_DIRECTIONS_BY_LANGUAGE[language]
    local nativeDirections = nativeByGameLanguage and nativeByGameLanguage[activeLanguageCode]
    if nativeDirections then
        local translated = getTextOrNull and getTextOrNull(nativeDirections[index])
        if type(translated) == "string" and translated ~= "" then
            return translated
        end
    end
    local direction = directions[index]
    if direction:sub(1, 3) == "UI_" then
        local translated = getTextOrNull and getTextOrNull(direction)
        if type(translated) == "string" and translated ~= "" then
            return translated
        end
        return LATIN_FALLBACK_DIRECTIONS[index]
    end
    return direction
end

local function gameLanguageCode()
    if not Translator or not Translator.getLanguage then return nil end
    local ok, languageCode = pcall(function()
        return Translator.getLanguage():name()
    end)
    return ok and languageCode or nil
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
    local o = ISUIElement.new(self, 0, 0, DEFAULT_WIDTH, HEIGHT)
    o.playerNum = playerNum
    o.heading = 0
    o.language = 1
    o.labelColor = DEFAULT_LABEL_COLOR
    o:initialise()
    o:instantiate()
    o:setRenderThisPlayerOnly(playerNum)
    o:setFollowGameWorld(false)
    o:addToUIManager()
    o:backMost()
    o:setVisible(false)
    return o
end

function ViewpointCompassUI:render()
    local width = self:getWidth()
    local centerX = width / 2
    local heading = self.heading
    local halfRange = width / (2 * PIXELS_PER_DEGREE)
    local labelColor = self.labelColor
    local layout = self.markerLayout or Markers.layout(2, false, 0)
    local markerOffset = layout.rulerY
    local points = {}
    if self.showMapMarkers then
        local player = getSpecificPlayer(self.playerNum)
        local state = player and Markers.refresh(player)
        points = Markers.project(player, state and state.markers or {}, heading, width, PIXELS_PER_DEGREE)
    end

    self:drawRect(0, markerOffset + 29, width, 1, 0.28, 0.82, 0.88, 0.91)

    for bearing = 0, 355, 5 do
        local delta = shortestAngle(bearing - heading)
        local isCardinal = bearing % 45 == 0
        if math.abs(delta) <= halfRange then
            local x = centerX + delta * PIXELS_PER_DEGREE
            local major = bearing % 15 == 0
            local tickHeight = isCardinal and 12 or (major and 10 or 6)
            self:drawRect(x, markerOffset + 29 - tickHeight, 1, tickHeight, (major or isCardinal) and 0.78 or 0.48,
                0.85, 0.9, 0.92)

            if (major or isCardinal) and math.abs(delta) > 5 then
                if isCardinal then
                    self:drawTextCentre(directionAtBearing(bearing, self.language, self.languageCode), x, markerOffset + 3,
                        labelColor.r, labelColor.g, labelColor.b, labelColor.a, UIFont.Small)
                else
                    self:drawTextCentre(string.format("%03d", bearing), x, markerOffset + 3,
                        0.76, 0.82, 0.85, 0.92, UIFont.Small)
                end
            end
        end
    end

    local headingText = string.format("%03d", math.floor(heading + 0.5) % 360)
    local directionText = directionAtBearing(heading, self.language, self.languageCode)
    local textGap = 3
    local horizontalPadding = 4
    local headingTextWidth = getTextManager():MeasureStringX(UIFont.Small, headingText)
    local directionTextWidth = getTextManager():MeasureStringX(UIFont.Small, directionText)
    local textWidth = headingTextWidth + textGap + directionTextWidth
    local centerWidth = textWidth + horizontalPadding * 2
    local textLeft = centerX - textWidth / 2
    self:drawRect(centerX - centerWidth / 2, markerOffset + 1, centerWidth, 23,
        0.72, 0.16, 0.19, 0.22)
    self:drawRectBorder(centerX - centerWidth / 2, markerOffset + 1, centerWidth, 23,
        0.58, 0.72, 0.78, 0.81)
    self:drawText(headingText, textLeft, markerOffset + 4, 0.96, 0.94, 0.94, 0.94, UIFont.Small)
    self:drawText(directionText, textLeft + headingTextWidth + textGap, markerOffset + 4,
        labelColor.r, labelColor.g, labelColor.b, labelColor.a, UIFont.Small)

    for _, point in ipairs(points) do
        local label = string.format("%dm", math.floor(point.distance + 0.5))
        if point.count > 0 then label = label .. " +" .. point.count end
        local labelWidth = getTextManager():MeasureStringX(UIFont.Small, label)
        local halfWidth = math.max(12, labelWidth / 2 + 4)
        local x = math.max(halfWidth, math.min(width - halfWidth, point.x))
        if layout.inside then
            if self.markerBackground then
                self:drawRect(x - halfWidth, 0, halfWidth * 2, HEIGHT, 0.96, 0.10, 0.12, 0.14)
            end
            Markers.drawIcon(self, point.marker, x - 8, 2, 16)
            self:drawTextCentre(label, x, 20, 0.96, 0.94, 0.94, 1, UIFont.Small)
        else
            Markers.drawIcon(self, point.marker, x - 10, layout.markerY + 18, 20)
            self:drawTextCentre(label, x, layout.markerY, 0.96, 0.94, 0.94, 1, UIFont.Small)
        end
    end
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
    local configuredWidth = compassWidth()
    local language = compassLanguage()
    local languageCode = gameLanguageCode()
    local labelColor = compassLabelColor()
    local heading = enabled and cameraHeading() or nil
    for playerNum, ui in pairs(uiByPlayer) do
        local player = getSpecificPlayer(playerNum)
        local state = player and Markers.refresh(player)
        ui.showMapMarkers = optionValue("ShowMapMarkers", true)
        ui.markerBackground = optionValue("MapMarkerBackground", false)
        ui.markerLayout = Markers.layout(optionValue("MapMarkerPosition", 2), ui.showMapMarkers,
            state and #state.markers or 0)
        if ui:getHeight() ~= ui.markerLayout.height then ui:setHeight(ui.markerLayout.height) end
        local visible = heading ~= nil
            and (not requireCompassItem or hasCompassItem(playerNum))
        if ui:getIsVisible() ~= visible then
            ui:setVisible(visible)
        end
        if visible then
            local left, top, screenWidth = playerScreenBounds(playerNum)
            local width = screenWidth and math.min(configuredWidth, screenWidth) or configuredWidth
            if ui:getWidth() ~= width then
                ui:setWidth(width)
            end
            if left and top and screenWidth then
                ui:setX(left + (screenWidth - ui:getWidth()) / 2)
                ui:setY(top + 18)
            end
            ui.heading = heading
            ui.language = language
            ui.languageCode = languageCode
            ui.labelColor = labelColor
        end
    end
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(playerNum)
        ensureCompass(playerNum)
    end)
end

local function initializePlayers()
    local playerCount = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, playerCount - 1 do
        if getSpecificPlayer(playerNum) then
            ensureCompass(playerNum)
        end
    end
    updateCompasses()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(initializePlayers)
end

if Events and Events.OnPreUIDraw then
    Events.OnPreUIDraw.Add(updateCompasses)
end

if Events and Events.OnSave then
    Events.OnSave.Add(function()
        for playerNum in pairs(uiByPlayer) do
            Markers.refresh(getSpecificPlayer(playerNum), true)
        end
    end)
end

initializePlayers()
