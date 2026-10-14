require "ISUI/Maps/ISWorldMapSymbols"
local Markers = ViewpointCompassMarkers or require "ViewpointCompass/Markers"
local Window = ViewpointCompassMarkerWindow or require "ViewpointCompass/MarkerWindow"
local Tool = ISWorldMapSymbolTool:derive("ViewpointCompassSelectMarkerTool")

function Tool:onMouseUp(x, y)
    local clicked = self.dragging and not self.dragMoved
    ISWorldMapSymbolTool.onMouseUp(self, x, y)
    if not clicked then return false end
    local index = self.symbolsAPI:hitTest(x, y)
    if index >= 0 then
        Markers.add(getSpecificPlayer(self.symbolsUI.playerNum), index)
        self.symbolsUI:setCurrentTool(nil)
    end
    return true
end

function Tool:onRightMouseDown(x, y)
    self.symbolsUI:setCurrentTool(nil)
    return true
end

function Tool:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function Tool:render()
    self.symbolsUI:hitTestAnnotations(self:getMouseX(), self:getMouseY(), "compass", function(symbol)
        return symbol ~= nil
    end)
end

local function addButton(panel, key, callback)
    local button = ISButton:new(panel.removeBtn.x, panel:getHeight(), panel.removeBtn.width,
        panel.removeBtn.height, Markers.text(key), panel, callback)
    button:initialise()
    button:instantiate()
    button.borderColor.a = 0
    panel:addChild(button)
    panel:insertNewLineOfButtons(button)
    panel:setHeight(button:getBottom() + 11)
    return button
end

if not ISWorldMapSymbols.viewpointCompassIntegrated then
    ISWorldMapSymbols.viewpointCompassIntegrated = true
    local originalCreate = ISWorldMapSymbols.createChildren
    function ISWorldMapSymbols:createChildren()
        originalCreate(self)
        if not self.isWorldMap then return end
        self.compassTool = Tool:new(self)
        self.compassAddButton = addButton(self, "Add", function(panel)
            panel.selectedSymbol = nil
            panel:toggleTool(panel.compassTool)
        end)
        self.compassAddButton.tooltip = Markers.text("Select")
        self.compassManageButton = addButton(self, "Manage", function(panel)
            panel:setCurrentTool(nil)
            if panel.compassMarkerWindow then
                panel.compassMarkerWindow:bringToTop()
                return
            end
            local window = Window:new(panel)
            window:initialise()
            window:addToUIManager()
            window:bringToTop()
            panel.compassMarkerWindow = window
        end)
    end

    local originalPrerender = ISWorldMapSymbols.prerender
    function ISWorldMapSymbols:prerender()
        originalPrerender(self)
        if self.compassAddButton then
            self.compassAddButton.borderColor.a = self.currentTool == self.compassTool and 1 or 0
        end
    end

    for _, method in ipairs({ "onMouseUpMap", "onKeyRelease", "onButtonClick" }) do
        local original = ISWorldMapSymbols[method]
        ISWorldMapSymbols[method] = function(panel, ...)
            local result = original(panel, ...)
            if panel.isWorldMap then Markers.refresh(getSpecificPlayer(panel.playerNum), true) end
            return result
        end
    end

    for _, callback in ipairs({
        { ISWorldMapSymbolTool_EditAnnotation, "onNoteEdited" },
        { ISWorldMapSymbolTool_EditAnnotation, "onSymbolEdited" },
        { ISWorldMapSymbolTool_RemoveAnnotation, "onConfirmRemoveAnnotation" },
    }) do
        local class, method = callback[1], callback[2]
        local original = class and class[method]
        if original then
            class[method] = function(tool, ...)
                local result = original(tool, ...)
                if tool.symbolsUI.isWorldMap then
                    Markers.refresh(getSpecificPlayer(tool.symbolsUI.playerNum), true)
                end
                return result
            end
        end
    end
end

ViewpointCompassMapIntegrationLoaded = true
return true
