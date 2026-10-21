require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
local Markers = ViewpointCompassMarkers or require "ViewpointCompass/Markers"
local ServerPolicy = ViewpointCompassServerPolicy or require "ViewpointCompass/ServerPolicy"
local Window = ISCollapsableWindow:derive("ViewpointCompassMarkerWindow")
ViewpointCompassMarkerWindow = Window
Window.instances = {}

function Window:new(symbolsUI, playerNum)
    playerNum = symbolsUI and symbolsUI.playerNum or playerNum or 0
    local x, y
    if symbolsUI and symbolsUI.mapUI then
        x = symbolsUI.mapUI:getAbsoluteX() + 40
        y = symbolsUI.mapUI:getAbsoluteY() + 40
    else
        x = (getCore():getScreenWidth() - 560) / 2
        y = (getCore():getScreenHeight() - 380) / 2
    end
    local o = ISCollapsableWindow.new(self, x, y, 560, 380)
    o.symbolsUI = symbolsUI
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o.title = Markers.text("Manage")
    o.resizable = false
    return o
end

function Window.open(playerNum, symbolsUI)
    playerNum = symbolsUI and symbolsUI.playerNum or playerNum or 0
    local current = Window.instances[playerNum]
        or (symbolsUI and symbolsUI.compassMarkerWindow)
    if current and current:getIsVisible() then
        current:bringToTop()
        return current
    end
    local window = Window:new(symbolsUI, playerNum)
    window:initialise()
    window:addToUIManager()
    window:bringToTop()
    Window.instances[playerNum] = window
    if symbolsUI then symbolsUI.compassMarkerWindow = window end
    return window
end

function Window.toggle(playerNum)
    playerNum = playerNum or 0
    local current = Window.instances[playerNum]
    if current and current:getIsVisible() then
        current:close()
        return nil
    end
    return Window.open(playerNum)
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.list = ISScrollingListBox:new(10, self:titleBarHeight() + 10, self.width - 20, 270)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = math.max(48, getTextManager():getFontHeight(UIFont.Small) * 2 + 10)
    self.list.doDrawItem = self.drawItem
    self.list.player = self.player
    self:addChild(self.list)
    local keys = { "Rename", "Locate", "Remove", "RemoveAll" }
    self.buttons = {}
    for index, key in ipairs(keys) do
        local button = ISButton:new(10 + (index - 1) * 135, self.list:getBottom() + 10,
            130, 28, Markers.text(key), self, self.onAction)
        button.internal = key
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self.buttons[index] = button
    end
    self:setHeight(self.buttons[1]:getBottom() + 15)
end

function Window.drawItem(list, y, item, alternate)
    local marker = item.item
    if list.selected == item.index then
        list:drawRect(0, y, list.width, list.itemheight, 0.35, 0.3, 0.4, 0.5)
    end
    Markers.drawIcon(list, marker, 8, y + 12, 24)
    local name = Markers.name(marker):gsub("[\r\n]", " ")
    local available = list.width - 65
    while #name > 0 and getTextManager():MeasureStringX(UIFont.Small, name) > available do
        name = name:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
    end
    list:drawText(name, 40, y + 4, 0.95, 0.95, 0.95, 1, UIFont.Small)
    local s = marker.signature
    list:drawText(string.format("%dm    (%d, %d)", math.floor(Markers.distance(list.player, marker) + 0.5),
        math.floor(s.x), math.floor(s.y)), 40, y + 25, 0.76, 0.82, 0.85, 1, UIFont.Small)
    return y + list.itemheight
end

function Window:update()
    if not ServerPolicy.getBoolean("AllowMapWaypoints") then self:close(); return end
    ISCollapsableWindow.update(self)
    if self.symbolsUI and not self.symbolsUI.mapUI:isReallyVisible() then self:close(); return end
    local state = Markers.refresh(self.player)
    if not state then return end
    if self.revision ~= state.revision then
        local selected = self.list.items[self.list.selected]
        selected = selected and selected.item
        local previousScroll = self.list:getYScroll()
        self.list:clear()
        for index, marker in ipairs(state.markers) do
            self.list:addItem(Markers.name(marker), marker)
            if marker == selected then self.list.selected = index end
        end
        self.list:setYScroll(previousScroll)
        self.revision = state.revision
    end
    for index, button in ipairs(self.buttons) do
        button:setEnable(index == 4 and #state.markers > 0 or index ~= 4 and self.list.items[self.list.selected] ~= nil)
    end
end

function Window:render()
    ISCollapsableWindow.render(self)
    if #self.list.items == 0 then
        self:drawTextCentre(Markers.text("Empty"), self.width / 2, self.list.y + 20,
            0.76, 0.82, 0.85, 1, UIFont.Small)
    end
end

function Window:onAction(button)
    local item = self.list.items[self.list.selected]
    local marker = item and item.item
    local action = button.internal
    if action == "Rename" and marker then
        local modal = ISTextBox:new(self.x + 40, self.y + 60, 380, 160, Markers.text("Rename"),
            Markers.name(marker), self, self.onRename, self.playerNum, marker)
        modal:initialise()
        modal:addToUIManager()
        modal:setAlwaysOnTop(true)
        modal.entry:focus()
    elseif action == "Locate" and marker then
        local state = Markers.refresh(self.player, true)
        for _, current in ipairs(state.markers) do
            if current == marker then
                local x, y = marker.signature.x, marker.signature.y
                if self.symbolsUI then
                    self.symbolsUI:setCurrentTool(nil)
                    self.symbolsUI.mapAPI:centerOn(x, y)
                    self:close()
                    return
                end
                if not ISWorldMap then require "ISUI/Maps/ISWorldMap" end
                if ISWorldMap and ISWorldMap.ShowWorldMap then
                    ISWorldMap.ShowWorldMap(self.playerNum, x, y, 18.0)
                    local map = ISWorldMap_instance
                    if map and map.mapAPI and map.symbolsUI then
                        map.mapAPI:centerOn(x, y)
                        map.mapAPI:setZoom(18.0)
                        self:close()
                    end
                end
                return
            end
        end
    elseif action == "Remove" and marker then
        Markers.remove(self.player, marker)
    elseif action == "RemoveAll" then
        local modal = ISModalDialog:new(self.x + 40, self.y + 60, 420, 160,
            Markers.text("Confirm"), true, self, self.onRemoveAll, self.playerNum)
        modal:initialise()
        modal:addToUIManager()
        modal:setAlwaysOnTop(true)
    end
end

function Window:onRename(button, marker)
    if button.internal == "OK" then Markers.rename(self.player, marker, button.parent.entry:getText()) end
end

function Window:onRemoveAll(button)
    if button.internal == "YES" then Markers.remove(self.player) end
end

function Window:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if Window.instances[self.playerNum] == self then Window.instances[self.playerNum] = nil end
    if self.symbolsUI and self.symbolsUI.compassMarkerWindow == self then
        self.symbolsUI.compassMarkerWindow = nil
    end
end

return Window
