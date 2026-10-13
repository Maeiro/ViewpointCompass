local Markers = require "ViewpointCompass/Markers"
local savedAdd, savedRefresh = Markers.add, Markers.refresh
local calls = 0
Markers.add = function(player, index) calls = calls + 1; assert(index == 2) end
Markers.refresh = function() return { markers = {} } end
local function class()
    local c = {}
    c.__index = c
    function c:derive() local child = {}; child.__index = child; return setmetatable(child, { __index = self }) end
    function c:new(panel) return setmetatable({ symbolsUI = panel, symbolsAPI = panel.symbolsAPI }, self) end
    return c
end
ISWorldMapSymbolTool = class()
function ISWorldMapSymbolTool:onMouseUp() self.dragging = false end
ISWorldMapSymbols = {
    createChildren = function(self) self.height = 200 end,
    prerender = function() end,
    onMouseUpMap = function() return true end,
    onKeyRelease = function() return false end,
    onButtonClick = function() return "original" end,
}
ISButton = {}
function ISButton:new(x, y, width, height, text, target, callback)
    return { x = x, y = y, width = width, height = height, text = text, target = target, callback = callback,
        borderColor = {}, initialise = function() end, instantiate = function() end,
        getBottom = function(self) return self.y + self.height end }
end
Keyboard = { KEY_ESCAPE = 1 }
function getSpecificPlayer() return {} end
package.loaded["ISUI/Maps/ISWorldMapSymbols"] = true
package.loaded["ViewpointCompass/MarkerWindow"] = {}
require "ViewpointCompass/MapIntegration"
local function panel(worldMap)
    return setmetatable({ isWorldMap = worldMap, removeBtn = { x = 10, width = 200, height = 24 },
        symbolsAPI = { hitTest = function() return 2 end }, playerNum = 0,
        getHeight = function(self) return self.height end,
        setHeight = function(self, height) self.height = height end,
        addChild = function() end, insertNewLineOfButtons = function() end,
        setCurrentTool = function(self, tool) self.currentTool = tool end,
        toggleTool = function(self, tool) self.currentTool = self.currentTool ~= tool and tool or nil end,
    }, { __index = ISWorldMapSymbols })
end
local map = panel(true)
map:createChildren()
assert(map.compassAddButton and map.compassManageButton, "main map buttons")
map.compassAddButton.callback(map)
assert(map.currentTool == map.compassTool, "selection activation")
local tool = map.compassTool
tool.dragging, tool.dragMoved = true, false
assert(tool:onMouseUp(50, 60) and calls == 1 and map.currentTool == nil, "click adds and exits")
tool.dragging, tool.dragMoved = true, true
assert(not tool:onMouseUp(50, 60) and calls == 1, "map drag does not select")
map:setCurrentTool(tool)
assert(tool:onRightMouseDown() and map.currentTool == nil, "right-click cancellation")
assert(tool:isKeyConsumed(Keyboard.KEY_ESCAPE), "escape consumed by selection")
local paper = panel(false)
paper:createChildren()
assert(not paper.compassAddButton and not paper.compassTool, "paper map unchanged")
assert(map:onButtonClick({}) == "original", "original callback preserved")
assert(map:onMouseUpMap(1, 1) == true and map:onKeyRelease(2) == false, "native returns preserved")
Markers.add, Markers.refresh = savedAdd, savedRefresh
print("map_integration_test: PASS")
