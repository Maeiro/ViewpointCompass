local savedMarkers = ViewpointCompassMarkers
ViewpointCompassMarkers = { text = function(key) return key end, refresh = function() return nil end }

ISCollapsableWindow = {}
function ISCollapsableWindow:derive()
    local child = {}
    child.__index = child
    return setmetatable(child, { __index = self })
end
function ISCollapsableWindow:new(x, y, width, height)
    return setmetatable({ x = x, y = y, width = width, height = height, visible = true }, self)
end
function ISCollapsableWindow:initialise() end
function ISCollapsableWindow:addToUIManager() end
function ISCollapsableWindow:bringToTop() self.raised = true end
function ISCollapsableWindow:getIsVisible() return self.visible end
function ISCollapsableWindow:update() end
function ISCollapsableWindow:close() self.visible = false end
function ISCollapsableWindow:removeFromUIManager() self.removed = true end

for _, name in ipairs({
    "ISUI/ISCollapsableWindow", "ISUI/ISScrollingListBox", "ISUI/ISButton",
    "ISUI/ISTextBox", "ISUI/ISModalDialog",
}) do
    package.loaded[name] = true
end

function getCore()
    return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end }
end
function getSpecificPlayer(playerNum) return { playerNum = playerNum } end

package.loaded["ViewpointCompass/MarkerWindow"] = nil
local Window = require "ViewpointCompass/MarkerWindow"
local standalone = Window.toggle(1)
assert(standalone and standalone.symbolsUI == nil and standalone.playerNum == 1, "hotkey window opens without a map")
assert(standalone.x == 680 and standalone.y == 350, "standalone window is centered")
standalone:update()
assert(standalone:getIsVisible(), "standalone window stays open without a map")
assert(Window.open(1) == standalone, "opening again reuses the active window")
assert(Window.toggle(1) == nil and standalone.removed, "hotkey toggles the window closed")
assert(Window.instances[1] == nil, "closed window is unregistered")

local symbolsUI = {
    playerNum = 2,
    mapUI = { getAbsoluteX = function() return 100 end, getAbsoluteY = function() return 200 end },
}
local mapWindow = Window.open(2, symbolsUI)
assert(mapWindow.symbolsUI == symbolsUI and symbolsUI.compassMarkerWindow == mapWindow,
    "map button keeps using the shared manager window")
mapWindow:close()
assert(symbolsUI.compassMarkerWindow == nil, "closing clears the map panel reference")

ViewpointCompassMarkers = savedMarkers
print("marker_window_test: PASS")
