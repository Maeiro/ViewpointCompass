require "PZAPI/ModOptions"
require "ISUI/ISUIElement"
local ServerPolicy = ViewpointCompassServerPolicy or require "ViewpointCompass/ServerPolicy"
local Markers = ViewpointCompassMarkers or require "ViewpointCompass/Markers"
if not ViewpointCompassMapIntegrationLoaded then
    require "ViewpointCompass/MapIntegration"
end

local MOD_ID = "ViewpointCompass"
local MarkerWindow = ViewpointCompassMarkerWindow or require "ViewpointCompass/MarkerWindow"
local DEFAULT_WIDTH = 520
local MIN_WIDTH = 360
local MAX_WIDTH = 1000
local HEIGHT = 42
local DIRECTION_ONLY_HEIGHT = 22
local PIXELS_PER_DEGREE = 6
local DEFAULT_SCALE = 1
local MIN_SCALE = 0.5
local MAX_SCALE = 2
local DEFAULT_FACTION_PLAYER_RANGE = 250
local MIN_FACTION_PLAYER_RANGE = 25
local MAX_FACTION_PLAYER_RANGE = 1000
local DEFAULT_ALIFE_MARKER_RANGE = 40
local MIN_ALIFE_MARKER_RANGE = 5
local MAX_ALIFE_MARKER_RANGE = 100
local ALIFE_NEW_MARKER_BLINK_MS = 2000
local DEFAULT_HOSTILE_CLOSE_BLINK_DISTANCE = 5
local DEFAULT_LABEL_COLOR = { r = 222 / 255, g = 178 / 255, b = 110 / 255, a = 1 }
local FactionPlayers = ViewpointCompassFactionPlayers or require "ViewpointCompass/FactionPlayers"
local ALIFE_STANCE_COLORS = {
    allied = { 0.25, 0.68, 1 },
    friendly = { 0.25, 0.9, 0.35 },
    neutral = { 0.88, 0.88, 0.88 },
    careful = { 1, 0.82, 0.12 },
    hostile = { 1, 0.2, 0.16 },
}
local ALIFE_STANCE_ORDER = { "hostile", "careful", "neutral", "friendly", "allied" }
local alifeMarkerStates = {}
local alifeIconTexture
local firearmIconTexture
local alifeBridge = rawget(_G, "ViewpointCompassALifeBridge")
if type(alifeBridge) ~= "table" then
    alifeBridge = { markers = {} }
    rawset(_G, "ViewpointCompassALifeBridge", alifeBridge)
end

local function uiText(key, fallback)
    local translated = getTextOrNull and getTextOrNull("UI_ViewpointCompass_" .. key)
    if type(translated) == "string" and translated ~= "" then return translated end
    return fallback
end

local LANGUAGES = {
    { key = "Language_English", fallback = "English" },
    { key = "Language_PortugueseBrazil", fallback = "Portuguese (Brazil)" },
    { key = "Language_ChineseSimplified", fallback = "Chinese (Simplified)" },
    { key = "Language_Russian", fallback = "Russian" },
    { key = "Language_Spanish", fallback = "Spanish" },
    { key = "Language_French", fallback = "French" },
    { key = "Language_German", fallback = "German" },
    { key = "Language_Japanese", fallback = "Japanese" },
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
local function addDirectionOnlyOption(target)
    target:addTickBox(
        "DirectionOnly",
        uiText("Options_DirectionOnly", "Show only the direction"),
        false,
        uiText("Options_DirectionOnlyTooltip",
            "Show only the current cardinal/intercardinal direction; hide the ruler, degrees, map markers, and faction players.")
    )
end

local function addWaypointManagerKeyOption(target)
    target:addKeyBind(
        "OpenWaypointManagerKey",
        uiText("Options_OpenWaypointManagerKey", "Open waypoint management"),
        Keyboard.KEY_LBRACKET,
        uiText("Options_OpenWaypointManagerKeyTooltip", "Open or close Compass Markers. Set to None to disable the shortcut.")
    )
end

local function addCompassScaleOption(target)
    target:addSlider("CompassScale", uiText("Options_CompassScale", "Compass size (%)"),
        MIN_SCALE * 100, MAX_SCALE * 100, 5, DEFAULT_SCALE * 100,
        uiText("Options_CompassScaleTooltip", "Scales the compass, including its labels and markers."))
end

local function addFactionPlayersOption(target)
    target:addTickBox(
        "ShowFactionPlayers",
        uiText("Options_ShowFactionPlayers", "Show nearby faction members on compass"),
        true,
        uiText("Options_ShowFactionPlayersTooltip",
            "Requires Viewpoint Compass on the server. Detection range is configurable below.")
    )
end

local function addFactionPlayerRangeOption(target)
    target:addSlider(
        "FactionPlayerRange",
        uiText("Options_FactionPlayerRange", "Faction player detection range (meters)"),
        MIN_FACTION_PLAYER_RANGE,
        MAX_FACTION_PLAYER_RANGE,
        25,
        DEFAULT_FACTION_PLAYER_RANGE,
        uiText("Options_FactionPlayerRangeTooltip",
            "Same-faction players are detected within this range. Requires the mod on the server.")
    )
end

local function addFactionPlayerPositionOption(target)
    local position = target:addComboBox(
        "FactionPlayerPosition",
        uiText("Options_FactionPlayerPosition", "Faction player marker position")
    )
    for index, key in ipairs({ "Above", "Inside", "Below" }) do
        position:addItem(Markers.text(key), index == 2)
    end
end

local function addALifeMarkerOptions(target)
    if not target:getOption("ShowALifeMarkers") then
        target:addTickBox(
            "ShowALifeMarkers",
            uiText("Options_ShowALifeMarkers", "Show A-Life NPCs on the compass"),
            true,
            uiText("Options_ShowALifeMarkersTooltip",
                "Requires Viewpoint Threat Detector. Hostile, Careful, Neutral, Friendly, and Allied NPCs use different outline colors.")
        )
    end
    if not target:getOption("ALifeMarkerRange") then
        target:addSlider(
            "ALifeMarkerRange",
            uiText("Options_ALifeMarkerRange", "A-Life compass detection range (meters)"),
            MIN_ALIFE_MARKER_RANGE,
            MAX_ALIFE_MARKER_RANGE,
            5,
            DEFAULT_ALIFE_MARKER_RANGE,
            uiText("Options_ALifeMarkerRangeTooltip",
                "Maximum distance for A-Life compass markers. One tile is shown as one meter.")
        )
    end
    if not target:getOption("BlinkNewALifeThreats") then
        target:addTickBox(
            "BlinkNewALifeThreats",
            uiText("Options_BlinkNewALifeThreats", "Blink new Hostile and Careful NPCs"),
            true,
            uiText("Options_BlinkNewALifeThreatsTooltip",
                "Hostile and Careful markers blink briefly when they first appear on the compass.")
        )
    end
    if not target:getOption("HostileCloseBlinkDistance") then
        target:addSlider(
            "HostileCloseBlinkDistance",
            uiText("Options_HostileCloseBlinkDistance", "Hostile close-range blink distance (meters)"),
            0,
            30,
            1,
            DEFAULT_HOSTILE_CLOSE_BLINK_DISTANCE,
            uiText("Options_HostileCloseBlinkDistanceTooltip",
                "Hostile markers keep blinking within this distance. Set to 0 to disable close-range blinking.")
        )
    end
end

local function organizeCompassOptions(target)
    local sections = {
        {
            title = "Options_Category_General",
            fallback = "General",
            options = { "ShowCompass", "RequireCompassItem", "OpenWaypointManagerKey" },
        },
        {
            title = "Options_Category_Display",
            fallback = "Compass Display",
            options = { "DirectionOnly", "CompassWidth", "CompassScale", "CompassLabelColor", "CompassLanguage" },
        },
        {
            title = "Options_Category_MapMarkers",
            fallback = "Map Markers",
            options = { "ShowMapMarkers", "MapMarkerBackground", "MapMarkerPosition" },
        },
        {
            title = "Options_Category_FactionPlayers",
            fallback = "Faction Players",
            options = { "ShowFactionPlayers", "FactionPlayerRange", "FactionPlayerPosition" },
        },
        {
            title = "Options_ALifeMarkersTitle",
            fallback = "A-Life Compass Markers",
            options = { "ShowALifeMarkers", "ALifeMarkerRange", "BlinkNewALifeThreats", "HostileCloseBlinkDistance" },
        },
    }
    local ordered = {}
    local included = {}
    for _, section in ipairs(sections) do
        ordered[#ordered + 1] = { type = "title", name = uiText(section.title, section.fallback) }
        for _, id in ipairs(section.options) do
            local option = target:getOption(id)
            if option then
                ordered[#ordered + 1] = option
                included[id] = true
            end
        end
    end
    for _, option in ipairs(target.data) do
        if option.type ~= "title" and (not option.id or not included[option.id]) then
            ordered[#ordered + 1] = option
        end
    end
    target.data = ordered
end

local function registerOptions()
    if not PZAPI or not PZAPI.ModOptions then return end
    options = PZAPI.ModOptions:getOptions(MOD_ID)
    if options then
        if not options:getOption("DirectionOnly") then addDirectionOnlyOption(options) end
        if not options:getOption("OpenWaypointManagerKey") then addWaypointManagerKeyOption(options) end
        if not options:getOption("CompassScale") then addCompassScaleOption(options) end
        if not options:getOption("ShowFactionPlayers") then addFactionPlayersOption(options) end
        if not options:getOption("FactionPlayerRange") then addFactionPlayerRangeOption(options) end
        if not options:getOption("FactionPlayerPosition") then addFactionPlayerPositionOption(options) end
        addALifeMarkerOptions(options)
        organizeCompassOptions(options)
        return
    end

    options = PZAPI.ModOptions:create(MOD_ID, uiText("Name", "Viewpoint Compass"))
    options:addTickBox("ShowCompass", uiText("Options_ShowCompass", "Show directional compass"), true)
    addDirectionOnlyOption(options)
    addWaypointManagerKeyOption(options)
    addFactionPlayersOption(options)
    addFactionPlayerRangeOption(options)
    addFactionPlayerPositionOption(options)
    addALifeMarkerOptions(options)
    options:addTickBox("ShowMapMarkers", Markers.text("Show"), true)
    options:addTickBox("MapMarkerBackground", Markers.text("Background"), false)
    local markerPosition = options:addComboBox("MapMarkerPosition", Markers.text("Position"))
    for index, key in ipairs({ "Above", "Inside", "Below" }) do
        markerPosition:addItem(Markers.text(key), index == 2)
    end
    options:addTickBox(
        "RequireCompassItem",
        uiText("Options_RequireCompassItem", "Require a Compass item to show the compass"),
        false,
        uiText("Options_RequireCompassItemTooltip",
            "When enabled, you must carry the vanilla Compass item in your inventory or a carried bag.")
    )
    options:addSlider("CompassWidth", uiText("Options_CompassWidth", "Compass width (pixels)"),
        MIN_WIDTH, MAX_WIDTH, 20, DEFAULT_WIDTH)
    addCompassScaleOption(options)
    options:addColorPicker(
        "CompassLabelColor",
        uiText("Options_CompassLabelColor", "Compass direction label color"),
        DEFAULT_LABEL_COLOR.r,
        DEFAULT_LABEL_COLOR.g,
        DEFAULT_LABEL_COLOR.b,
        DEFAULT_LABEL_COLOR.a
    )
    local languageOption = options:addComboBox("CompassLanguage",
        uiText("Options_CompassLanguage", "Compass direction language"))
    for index, language in ipairs(LANGUAGES) do
        languageOption:addItem(uiText(language.key, language.fallback), index == 1)
    end
    organizeCompassOptions(options)
end

registerOptions()

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(registerOptions)
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

local function drawTextScaled(ui, text, x, y, scale, r, g, b, a)
    ui:drawTextZoomed(text, x, y, scale, r, g, b, a, UIFont.Small)
end

local function drawTextCentreScaled(ui, text, x, y, scale, r, g, b, a)
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, text) * scale
    drawTextScaled(ui, text, x - textWidth / 2, y, scale, r, g, b, a)
end

local function drawMarkerDistance(ui, label, x, y, scale, alpha)
    alpha = alpha or 1
    drawTextCentreScaled(ui, label, x + scale, y + scale, scale, 0.02, 0.02, 0.02, 0.78 * alpha)
    drawTextCentreScaled(ui, label, x, y, scale, 0.96, 0.94, 0.94, alpha)
end

local function alifeIcon()
    if alifeIconTexture then return alifeIconTexture end
    local ok, texture = pcall(getTexture, "media/ui/ThreatAlert/alife.png")
    if ok and texture then
        alifeIconTexture = texture
        return texture
    end
    return nil
end

local function firearmIcon()
    if firearmIconTexture then return firearmIconTexture end
    local ok, texture = pcall(getTexture, "media/textures/Item_HandGun3")
    if ok and texture then
        firearmIconTexture = texture
        return texture
    end
    return nil
end

local function alifeBlinking(marker, now, blinkNewThreats, hostileCloseDistance)
    local id = tostring(marker.id)
    local stance = marker.stance
    local state = alifeMarkerStates[id]
    if not state or state.stance ~= stance then
        state = { stance = stance }
        if blinkNewThreats and (stance == "hostile" or stance == "careful") then
            state.blinkUntil = now + ALIFE_NEW_MARKER_BLINK_MS
        end
        alifeMarkerStates[id] = state
    end
    local closeHostile = stance == "hostile" and hostileCloseDistance > 0
        and marker.distance <= hostileCloseDistance
    return closeHostile or (state.blinkUntil and now < state.blinkUntil) or false
end

local function projectALifeMarkers(player, markers, heading, width, pixelsPerDegree, scale,
        maxDistance, blinkNewThreats, hostileCloseDistance)
    if not player or type(heading) ~= "number" or type(width) ~= "number"
            or type(pixelsPerDegree) ~= "number" then
        alifeMarkerStates = {}
        return {}, { left = {}, right = {} }
    end

    local playerX, playerY
    local ok = pcall(function() playerX, playerY = player:getX(), player:getY() end)
    if not ok or type(playerX) ~= "number" or type(playerY) ~= "number" then
        alifeMarkerStates = {}
        return {}, { left = {}, right = {} }
    end

    local now = type(getTimestampMs) == "function" and getTimestampMs() or 0
    local halfRange = width / (2 * pixelsPerDegree)
    local maxDistanceSquared = maxDistance * maxDistance
    local active = {}
    local visible = {}
    local edgeMarkers = { left = {}, right = {} }

    for _, marker in ipairs(markers or {}) do
        local color = type(marker) == "table" and ALIFE_STANCE_COLORS[marker.stance]
        if color and marker.id ~= nil and type(marker.x) == "number" and type(marker.y) == "number" then
            local dx, dy = marker.x - playerX, marker.y - playerY
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= maxDistance and distance * distance <= maxDistanceSquared then
                local id = tostring(marker.id)
                active[id] = true
                local bearing = (math.deg(math.atan2(dy, dx)) + 90) % 360
                local delta = shortestAngle(bearing - heading)
                local blinking = alifeBlinking({ id = id, stance = marker.stance, distance = distance },
                    now, blinkNewThreats, hostileCloseDistance)
                if math.abs(delta) <= halfRange then
                    local x = width / 2 + delta * pixelsPerDegree
                    local grouped
                    for _, point in ipairs(visible) do
                        if point.stance == marker.stance and math.abs(point.x - x) < 20 * scale then
                            grouped = point
                            break
                        end
                    end
                    if grouped then
                        grouped.count = grouped.count + 1
                        grouped.armedCount = grouped.armedCount + (marker.armed and 1 or 0)
                        grouped.blinking = grouped.blinking or blinking
                        if distance < grouped.distance then
                            grouped.x, grouped.distance = x, distance
                            grouped.marker = marker
                        end
                    else
                        visible[#visible + 1] = {
                            x = x,
                            distance = distance,
                            count = 1,
                            armedCount = marker.armed and 1 or 0,
                            stance = marker.stance,
                            marker = marker,
                            blinking = blinking,
                        }
                    end
                else
                    local side = delta < 0 and "left" or "right"
                    local group = edgeMarkers[side][marker.stance]
                    if not group then
                        group = { stance = marker.stance, marker = marker, distance = distance,
                            count = 0, armedCount = 0, blinking = false }
                        edgeMarkers[side][marker.stance] = group
                    end
                    group.count = group.count + 1
                    group.armedCount = group.armedCount + (marker.armed and 1 or 0)
                    group.blinking = group.blinking or blinking
                    if distance < group.distance then
                        group.marker, group.distance = marker, distance
                    end
                end
            end
        end
    end

    for id in pairs(alifeMarkerStates) do
        if not active[id] then alifeMarkerStates[id] = nil end
    end
    table.sort(visible, function(a, b) return a.x < b.x end)
    for _, side in ipairs({ "left", "right" }) do
        local ordered = {}
        for _, stance in ipairs(ALIFE_STANCE_ORDER) do
            local group = edgeMarkers[side][stance]
            if group then ordered[#ordered + 1] = group end
        end
        edgeMarkers[side] = ordered
    end
    return visible, edgeMarkers
end

local function alifeMarkerAlpha(blinking, now)
    if not blinking then return 1 end
    return 0.25 + 0.75 * (0.5 + 0.5 * math.sin(now / 1000 * math.pi * 4))
end

local function drawALifeMarkerIcon(ui, point, x, y, scale, alpha)
    local color = ALIFE_STANCE_COLORS[point.stance]
    local size = 16 * scale
    local outline = 2 * scale
    ui:drawRectBorder(x - outline, y - outline, size + outline * 2, size + outline * 2,
        alpha, color[1], color[2], color[3])
    local texture = alifeIcon()
    if texture then
        ui:drawTextureScaled(texture, x, y, size, size, 1, 1, 1, alpha)
    else
        drawTextCentreScaled(ui, "A", x + size / 2, y, scale, color[1], color[2], color[3], alpha)
    end
end

local function drawFirearmMarkerIcon(ui, x, y, scale, alpha)
    local texture = firearmIcon()
    if texture then
        local size = 12 * scale
        ui:drawTextureScaled(texture, x - size / 2, y, size, size, 1, 1, 1, alpha)
    end
end

local function compassWidth()
    local width = optionValue("CompassWidth", DEFAULT_WIDTH)
    if type(width) ~= "number" then return DEFAULT_WIDTH end
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, width))
end

local function compassScale()
    local scale = optionValue("CompassScale", DEFAULT_SCALE * 100)
    if type(scale) ~= "number" then return DEFAULT_SCALE end
    return math.max(MIN_SCALE, math.min(MAX_SCALE, scale / 100))
end

local function factionPlayerRange()
    local range = optionValue("FactionPlayerRange", DEFAULT_FACTION_PLAYER_RANGE)
    if type(range) ~= "number" then return DEFAULT_FACTION_PLAYER_RANGE end
    return math.max(MIN_FACTION_PLAYER_RANGE, math.min(MAX_FACTION_PLAYER_RANGE, range))
end

local function alifeMarkerRange()
    local range = optionValue("ALifeMarkerRange", DEFAULT_ALIFE_MARKER_RANGE)
    if type(range) ~= "number" then return DEFAULT_ALIFE_MARKER_RANGE end
    return math.max(MIN_ALIFE_MARKER_RANGE, math.min(MAX_ALIFE_MARKER_RANGE, range))
end

local function hostileCloseBlinkDistance()
    local distance = optionValue("HostileCloseBlinkDistance", DEFAULT_HOSTILE_CLOSE_BLINK_DISTANCE)
    if type(distance) ~= "number" then return DEFAULT_HOSTILE_CLOSE_BLINK_DISTANCE end
    return math.max(0, math.min(30, distance))
end

local function markerPosition(name)
    local position = optionValue(name, 2)
    if type(position) ~= "number" or position < 1 or position > 3 then return 2 end
    return math.floor(position)
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
    local scale = self.scale or DEFAULT_SCALE
    if self.directionOnly then
        local direction = directionAtBearing(heading, self.language, self.languageCode)
        local labelColor = self.labelColor
        drawTextCentreScaled(self, direction, centerX, 2 * scale, scale,
            labelColor.r, labelColor.g, labelColor.b, labelColor.a)
        return
    end
    local pixelsPerDegree = PIXELS_PER_DEGREE * scale
    local halfRange = width / (2 * pixelsPerDegree)
    local labelColor = self.labelColor
    local layout = self.markerLayout or Markers.layout(2, false, 0)
    local markerOffset = layout.rulerY
    local points = {}
    if self.showMapMarkers then
        local player = getSpecificPlayer(self.playerNum)
        local state = player and Markers.refresh(player)
        points = Markers.project(player, state and state.markers or {}, heading, width, pixelsPerDegree, scale)
    end

    local rulerY = markerOffset + 29 * scale
    local lineThickness = math.max(1, scale)
    self:drawRect(0, rulerY, width, lineThickness, 0.28, 0.82, 0.88, 0.91)

    for bearing = 0, 355, 5 do
        local delta = shortestAngle(bearing - heading)
        local isCardinal = bearing % 45 == 0
        if math.abs(delta) <= halfRange then
            local x = centerX + delta * pixelsPerDegree
            local major = bearing % 15 == 0
            local tickHeight = (isCardinal and 12 or (major and 10 or 6)) * scale
            self:drawRect(x, rulerY - tickHeight, lineThickness, tickHeight, (major or isCardinal) and 0.78 or 0.48,
                0.85, 0.9, 0.92)

            if (major or isCardinal) and math.abs(delta) > 5 then
                if isCardinal then
                    drawTextCentreScaled(self,
                        directionAtBearing(bearing, self.language, self.languageCode), x, markerOffset + 3 * scale,
                        scale, labelColor.r, labelColor.g, labelColor.b, labelColor.a)
                else
                    drawTextCentreScaled(self, string.format("%03d", bearing), x, markerOffset + 3 * scale,
                        scale, 0.76, 0.82, 0.85, 0.92)
                end
            end
        end
    end

    local headingText = string.format("%03d", math.floor(heading + 0.5) % 360)
    local directionText = directionAtBearing(heading, self.language, self.languageCode)
    local textGap = 3 * scale
    local horizontalPadding = 4 * scale
    local headingTextWidth = getTextManager():MeasureStringX(UIFont.Small, headingText) * scale
    local directionTextWidth = getTextManager():MeasureStringX(UIFont.Small, directionText) * scale
    local textWidth = headingTextWidth + textGap + directionTextWidth
    local centerWidth = textWidth + horizontalPadding * 2
    local textLeft = centerX - textWidth / 2
    self:drawRect(centerX - centerWidth / 2, markerOffset + scale, centerWidth, 23 * scale,
        0.72, 0.16, 0.19, 0.22)
    self:drawRectBorder(centerX - centerWidth / 2, markerOffset + scale, centerWidth, 23 * scale,
        0.58, 0.72, 0.78, 0.81)
    drawTextScaled(self, headingText, textLeft, markerOffset + 4 * scale, scale, 0.96, 0.94, 0.94, 0.94)
    drawTextScaled(self, directionText, textLeft + headingTextWidth + textGap, markerOffset + 4 * scale,
        scale, labelColor.r, labelColor.g, labelColor.b, labelColor.a)

    for _, point in ipairs(points) do
        local label = string.format("%dm", math.floor(point.distance + 0.5))
        if point.count > 0 then label = label .. " +" .. point.count end
        local labelWidth = getTextManager():MeasureStringX(UIFont.Small, label) * scale
        local halfWidth = math.max(12 * scale, labelWidth / 2 + 4 * scale)
        local x = math.max(halfWidth, math.min(width - halfWidth, point.x))
        if layout.inside then
            if self.markerBackground then
                self:drawRect(x - halfWidth, layout.rulerY, halfWidth * 2, HEIGHT * scale,
                    0.96, 0.10, 0.12, 0.14)
            end
            Markers.drawIcon(self, point.marker, x - 8 * scale, layout.rulerY + 2 * scale, 16 * scale, scale)
            drawMarkerDistance(self, label, x, layout.rulerY + 20 * scale, scale)
        else
            Markers.drawIcon(self, point.marker, x - 10 * scale, layout.markerY + 18 * scale,
                20 * scale, scale)
            drawMarkerDistance(self, label, x, layout.markerY, scale)
        end
    end

    local playerTexture = getTexture("media/ui/ViewpointCompass/faction_player.png")
    for _, point in ipairs(self.factionPlayerPoints or {}) do
        local label = self.factionPlayerShowDistance and point.distance
            and string.format("%dm", math.floor(point.distance + 0.5)) or ""
        if point.count > 0 then label = label .. (label == "" and "+" or " +") .. point.count end
        local labelWidth = label ~= "" and getTextManager():MeasureStringX(UIFont.Small, label) * scale or 0
        local halfWidth = math.max(10 * scale, labelWidth / 2 + 3 * scale)
        local x = math.max(halfWidth, math.min(width - halfWidth, point.x))
        if self.factionPlayerInside and layout.inside then
            for _, mapPoint in ipairs(points) do
                if math.abs(x - mapPoint.x) < 24 * scale then
                    local offset = x < width / 2 and -24 * scale or 24 * scale
                    if x + offset < halfWidth or x + offset > width - halfWidth then
                        offset = -offset
                    end
                    x = math.max(halfWidth, math.min(width - halfWidth, x + offset))
                    break
                end
            end
        end
        local markerY = self.factionPlayerY or 0
        if self.factionPlayerInside then
            if playerTexture then
                self:drawTextureScaled(playerTexture, x - 8 * scale, markerY + 2 * scale,
                    16 * scale, 16 * scale, 1, 1, 1, 1)
            else
                self:drawRect(x - 4 * scale, markerY + 3 * scale, 8 * scale, 8 * scale, 1, 0.22, 0.86, 0.22)
                self:drawRect(x - 7 * scale, markerY + 12 * scale, 14 * scale, 8 * scale, 1, 0.22, 0.86, 0.22)
            end
            if label ~= "" then drawMarkerDistance(self, label, x, markerY + 20 * scale, scale) end
        else
            if playerTexture then
                self:drawTextureScaled(playerTexture, x - 10 * scale, markerY + 18 * scale,
                    20 * scale, 20 * scale, 1, 1, 1, 1)
            else
                self:drawRect(x - 5 * scale, markerY + 20 * scale, 10 * scale, 10 * scale, 1, 0.22, 0.86, 0.22)
                self:drawRect(x - 9 * scale, markerY + 31 * scale, 18 * scale, 10 * scale, 1, 0.22, 0.86, 0.22)
            end
            if label ~= "" then drawMarkerDistance(self, label, x, markerY, scale) end
        end
    end

    local markerY = markerOffset + 2 * scale
    local now = type(getTimestampMs) == "function" and getTimestampMs() or 0
    local occupied = {}
    for _, point in ipairs(points) do occupied[#occupied + 1] = { x = point.x, halfWidth = 14 * scale } end
    for _, point in ipairs(self.factionPlayerPoints or {}) do
        occupied[#occupied + 1] = { x = point.x, halfWidth = 14 * scale }
    end
    for _, point in ipairs(self.alifeMarkerPoints or {}) do
        local label = string.format("%dm", math.floor(point.distance + 0.5))
        if point.count > 1 then label = label .. " +" .. tostring(point.count - 1) end
        local labelWidth = getTextManager():MeasureStringX(UIFont.Small, label) * scale
        local halfWidth = math.max(12 * scale, labelWidth / 2 + 4 * scale)
        local x = math.max(halfWidth, math.min(width - halfWidth, point.x))
        local attempts = 0
        while attempts < 8 do
            local conflict
            for _, other in ipairs(occupied) do
                if math.abs(x - other.x) < halfWidth + other.halfWidth + 2 * scale then
                    conflict = true
                    break
                end
            end
            if not conflict then break end
            attempts = attempts + 1
            local direction = x < width / 2 and -1 or 1
            local shifted = x + direction * (halfWidth + 16 * scale)
            if shifted < halfWidth or shifted > width - halfWidth then
                shifted = x - direction * (halfWidth + 16 * scale)
            end
            x = math.max(halfWidth, math.min(width - halfWidth, shifted))
        end
        occupied[#occupied + 1] = { x = x, halfWidth = halfWidth }
        local alpha = alifeMarkerAlpha(point.blinking, now)
        drawALifeMarkerIcon(self, point, x - 8 * scale, markerY, scale, alpha)
        drawMarkerDistance(self, label, x, markerY + 20 * scale, scale, alpha)
        if point.armedCount > 0 then
            drawFirearmMarkerIcon(self, x, markerY + 34 * scale, scale, alpha)
        end
    end

    local edgeMarkers = self.alifeEdgeMarkers or { left = {}, right = {} }
    for _, side in ipairs({ "left", "right" }) do
        for index, point in ipairs(edgeMarkers[side] or {}) do
            local x = side == "left"
                and (6 + (index - 1) * 34) * scale
                or width - (6 + (index - 1) * 34) * scale
            local color = ALIFE_STANCE_COLORS[point.stance]
            local arrow = side == "left" and "<" or ">"
            local label = string.format("%dm", math.floor(point.distance + 0.5))
            if point.count > 1 then label = label .. " +" .. tostring(point.count - 1) end
            local alpha = alifeMarkerAlpha(point.blinking, now)
            local arrowScale = 1.5 * scale
            drawTextCentreScaled(self, arrow, x + scale, markerY + scale, arrowScale,
                0.02, 0.02, 0.02, 0.85 * alpha)
            for _, offset in ipairs({ -0.5, 0, 0.5 }) do
                drawTextCentreScaled(self, arrow, x + offset * scale, markerY, arrowScale,
                    color[1], color[2], color[3], alpha)
            end
            drawMarkerDistance(self, label, x, markerY + 20 * scale, scale, alpha)
            if point.armedCount > 0 then
                drawFirearmMarkerIcon(self, x, markerY + 34 * scale, scale, alpha)
            end
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
    local directionOnly = optionValue("DirectionOnly", false)
    local requireCompassItem = optionValue("RequireCompassItem", false)
        or ServerPolicy.getBoolean("RequireCompassItem")
    local showFactionPlayers = optionValue("ShowFactionPlayers", true)
        and ServerPolicy.getBoolean("AllowFactionPlayers")
    local factionRange = ServerPolicy.limitFactionPlayerRange(factionPlayerRange())
    local mapPosition = markerPosition("MapMarkerPosition")
    local factionPlayerPosition = markerPosition("FactionPlayerPosition")
    local scale = compassScale()
    local configuredWidth = compassWidth() * scale
    local language = compassLanguage()
    local languageCode = gameLanguageCode()
    local labelColor = compassLabelColor()
    local heading = enabled and cameraHeading() or nil
    local showALifeMarkers = enabled and not directionOnly and heading ~= nil
        and optionValue("ShowALifeMarkers", true)
    if showALifeMarkers and requireCompassItem then
        showALifeMarkers = hasCompassItem(0)
    end
    alifeBridge.requested = showALifeMarkers == true
    alifeBridge.range = alifeMarkerRange()
    if not alifeBridge.requested then alifeMarkerStates = {} end
    local alifeMarkers = alifeBridge.requested and type(alifeBridge.markers) == "table"
        and alifeBridge.markers or {}
    for playerNum, ui in pairs(uiByPlayer) do
        local player = getSpecificPlayer(playerNum)
        local state = not directionOnly and player and Markers.refresh(player)
        local peers = showFactionPlayers and heading and FactionPlayers.getPlayers() or {}
        local nearbyFactionPlayers = not directionOnly and player
            and FactionPlayers.hasNearby(player, peers, factionRange)
        local left, top, screenWidth = playerScreenBounds(playerNum)
        local width = screenWidth and math.min(configuredWidth, screenWidth) or configuredWidth
        ui.scale = scale
        ui.directionOnly = directionOnly
        ui.showMapMarkers = not directionOnly and optionValue("ShowMapMarkers", true)
            and ServerPolicy.getBoolean("AllowMapWaypoints")
        ui.markerBackground = optionValue("MapMarkerBackground", false)
        local mapMarkerCount = state and #state.markers or 0
        local hasMapMarkers = ui.showMapMarkers and mapMarkerCount > 0
        local hasNearbyPlayers = not directionOnly and nearbyFactionPlayers == true
        local combinedLayout = FactionPlayers.layout(
            mapPosition, hasMapMarkers, factionPlayerPosition, hasNearbyPlayers, HEIGHT * scale, scale
        )
        local layout = Markers.layout(mapPosition, ui.showMapMarkers, mapMarkerCount, scale)
        layout.rulerY = combinedLayout.rulerY
        layout.height = combinedLayout.height
        layout.inside = combinedLayout.mapInside
        layout.markerY = combinedLayout.mapY
        ui.markerLayout = layout
        ui.factionPlayerInside = combinedLayout.playerInside
        ui.factionPlayerY = combinedLayout.playerY
        ui.factionPlayerPoints = hasNearbyPlayers
            and FactionPlayers.project(player, peers, heading, width,
                PIXELS_PER_DEGREE * scale, scale, factionRange,
                ServerPolicy.getBoolean("ShowFactionPlayerDistance")) or {}
        ui.factionPlayerShowDistance = ServerPolicy.getBoolean("ShowFactionPlayerDistance")
        ui.alifeMarkerPoints, ui.alifeEdgeMarkers = projectALifeMarkers(
            player,
            alifeMarkers,
            heading,
            width,
            PIXELS_PER_DEGREE * scale,
            scale,
            alifeMarkerRange(),
            optionValue("BlinkNewALifeThreats", true),
            hostileCloseBlinkDistance()
        )
        ui.hasArmedALifeMarker = false
        for _, point in ipairs(ui.alifeMarkerPoints) do
            if point.armedCount > 0 then ui.hasArmedALifeMarker = true end
        end
        for _, side in ipairs({ "left", "right" }) do
            for _, point in ipairs(ui.alifeEdgeMarkers[side]) do
                if point.armedCount > 0 then ui.hasArmedALifeMarker = true end
            end
        end
        local height = directionOnly and DIRECTION_ONLY_HEIGHT * scale
            or layout.height + (ui.hasArmedALifeMarker and 6 * scale or 0)
        if ui:getHeight() ~= height then ui:setHeight(height) end
        local visible = heading ~= nil
            and (not requireCompassItem or hasCompassItem(playerNum))
        if ui:getIsVisible() ~= visible then
            ui:setVisible(visible)
        end
        if visible then
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
    local initializedCount = 0
    for playerNum = 0, playerCount - 1 do
        if getSpecificPlayer(playerNum) then
            ensureCompass(playerNum)
            initializedCount = initializedCount + 1
        end
    end
    if initializedCount > 0 then updateCompasses() end
    return initializedCount == playerCount and initializedCount > 0
end

local function retryPlayerInitialization()
    if initializePlayers() then
        Events.OnTick.Remove(retryPlayerInitialization)
    end
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(playerNum)
        ensureCompass(playerNum)
        retryPlayerInitialization()
    end)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        registerOptions()
        retryPlayerInitialization()
    end)
end

if Events and Events.OnPreUIDraw then
    Events.OnPreUIDraw.Add(updateCompasses)
end

if Events and Events.OnTick then
    Events.OnTick.Add(function()
        FactionPlayers.update(
            optionValue("ShowCompass", true) and optionValue("ShowFactionPlayers", true),
            factionPlayerRange()
        )
    end)
end

if Events and Events.OnKeyPressed then
    Events.OnKeyPressed.Add(function(key)
        local player = getSpecificPlayer(0)
        if not player or key ~= optionValue("OpenWaypointManagerKey", Keyboard.KEY_LBRACKET) then return end
        if not ServerPolicy.getBoolean("AllowMapWaypoints") then return end
        MarkerWindow.toggle(player:getPlayerNum())
    end)
end

if Events and Events.OnSave then
    Events.OnSave.Add(function()
        for playerNum in pairs(uiByPlayer) do
            Markers.refresh(getSpecificPlayer(playerNum), true)
        end
    end)
end

if not initializePlayers() and Events and Events.OnTick then
    Events.OnTick.Add(retryPlayerInitialization)
end

ViewpointCompassLuaLoaded = true
