local Markers = { states = setmetatable({}, { __mode = "k" }) }
local KEY = "ViewpointCompassMarkers"
local fields = { "x", "y", "r", "g", "b", "a", "scale", "rotation", "anchorX", "anchorY", "minZoom", "maxZoom" }
local fallback = {
    Add = "Add to Compass", Manage = "Compass Markers", Show = "Show map markers",
    Rename = "Rename", Locate = "Locate on map", Remove = "Remove", RemoveAll = "Remove All",
    Confirm = "Remove all compass markers? Map annotations will be kept.",
    Empty = "No compass markers. Use Add to Compass, then click a map annotation.",
    Select = "Click a map annotation. Esc or right click cancels.", Note = "Note",
    Position = "Map marker position", Above = "Above the compass", Inside = "Inside the compass",
    Below = "Below the compass",
}

function Markers.text(key)
    return (getTextOrNull and getTextOrNull("UI_ViewpointCompass_Markers_" .. key)) or fallback[key] or key
end

function Markers.layout(position, enabled, count)
    if not enabled or count == 0 then return { rulerY = 0, markerY = 0, height = 42 } end
    if position == 2 then return { rulerY = 0, markerY = 0, height = 42, inside = true } end
    if position == 3 then return { rulerY = 0, markerY = 42, height = 84 } end
    return { rulerY = 42, markerY = 0, height = 84 }
end

local function snapshot(symbol)
    local value = { text = ViewpointCompassMap.isText(symbol), content = ViewpointCompassMap.getContent(symbol) or "",
        style = ViewpointCompassMap.getStyle(symbol) }
    for _, field in ipairs(fields) do
        value[field] = ViewpointCompassMap.getNumber(symbol, field)
    end
    return value
end

local function matches(a, b)
    if not a or not b or a.text ~= b.text or a.content ~= b.content or a.style ~= b.style then return false end
    for _, field in ipairs(fields) do
        if a[field] ~= b[field] then return false end
    end
    return true
end

local function save(player, state)
    local records = {}
    for _, marker in ipairs(state.markers) do
        records[#records + 1] = { index = marker.index, signature = marker.signature, name = marker.name }
    end
    player:getModData()[KEY] = { version = 1, records = records }
    state.revision = state.revision + 1
end

function Markers.refresh(player, force)
    if not player or not ViewpointCompassMap then return nil end
    local state = Markers.states[player]
    if not state then
        state = { markers = {}, revision = 0 }
        Markers.states[player] = state
    end
    local now = getTimestampMs()
    if not force and state.lastRefresh and now - state.lastRefresh < 250 then return state end
    state.lastRefresh = now
    local collection = ViewpointCompassMap.getCollection()
    if not collection then return state end
    local symbols, indices, signatures = {}, {}, {}
    for index = 0, ViewpointCompassMap.getCount(collection) - 1 do
        local symbol = ViewpointCompassMap.getSymbol(collection, index)
        symbols[index] = symbol
        indices[symbol] = index
    end
    local changed = false
    if not state.restored then
        local data = player:getModData()[KEY]
        for _, record in ipairs(data and data.records or {}) do
            local found, count
            count = 0
            for index, symbol in pairs(symbols) do
                signatures[index] = signatures[index] or snapshot(symbol)
                if matches(record.signature, signatures[index]) then
                    found, count = index, count + 1
                end
            end
            -- Even a matching saved index is unsafe when identical annotations exist.
            if count == 1 then
                local duplicate = false
                for _, marker in ipairs(state.markers) do
                    if marker.symbol == symbols[found] then duplicate = true end
                end
                if not duplicate then
                    state.markers[#state.markers + 1] = {
                        symbol = symbols[found], index = found, signature = signatures[found], name = record.name,
                        generation = ViewpointCompassMap.getGeneration(collection, symbols[found]),
                    }
                end
            end
        end
        state.restored = true
        state.collection = collection
        changed = true
    elseif state.collection ~= collection then
        -- A replaced collection cannot safely inherit live references.
        state.restored = false
        state.markers = {}
        return Markers.refresh(player, true)
    end
    for index = #state.markers, 1, -1 do
        local marker = state.markers[index]
        local currentIndex = indices[marker.symbol]
        if currentIndex == nil or marker.generation ~= ViewpointCompassMap.getGeneration(collection, marker.symbol) then
            table.remove(state.markers, index)
            changed = true
        else
            local current = snapshot(marker.symbol)
            if marker.index ~= currentIndex or not matches(marker.signature, current) then
                marker.index, marker.signature = currentIndex, current
                changed = true
            end
        end
    end
    if changed then save(player, state) end
    return state
end

function Markers.add(player, index)
    local state = Markers.refresh(player, true)
    if not state then return end
    local symbol = ViewpointCompassMap.getSymbol(state.collection, index)
    if not symbol then return end
    for _, marker in ipairs(state.markers) do
        if marker.symbol == symbol then return end
    end
    state.markers[#state.markers + 1] = { symbol = symbol, index = index, signature = snapshot(symbol),
        generation = ViewpointCompassMap.getGeneration(state.collection, symbol) }
    save(player, state)
end

function Markers.rename(player, marker, name)
    local state = Markers.refresh(player, true)
    for _, current in ipairs(state and state.markers or {}) do
        if current == marker then
            marker.name = name:match("^%s*(.-)%s*$")
            if marker.name == "" then marker.name = nil end
            save(player, state)
            return
        end
    end
end

function Markers.remove(player, marker)
    local state = Markers.refresh(player, true)
    if not state then return end
    for index = #state.markers, 1, -1 do
        if not marker or state.markers[index] == marker then table.remove(state.markers, index) end
    end
    save(player, state)
end

function Markers.name(marker)
    if marker.name then return marker.name end
    local s = marker.signature
    if s.text then return ViewpointCompassMap.getLabel(marker.symbol) or Markers.text("Note") end
    return string.format("%s (%d, %d)", s.content, math.floor(s.x), math.floor(s.y))
end

function Markers.distance(player, marker)
    local s = marker.signature
    local dx, dy = s.x - player:getX(), s.y - player:getY()
    return math.sqrt(dx * dx + dy * dy)
end

function Markers.project(player, markers, heading, width, pixelsPerDegree)
    local points = {}
    for _, marker in ipairs(markers) do
        local s = marker.signature
        local dx, dy = s.x - player:getX(), s.y - player:getY()
        local bearing = (math.deg(math.atan2(dy, dx)) + 90) % 360
        local delta = (bearing - heading + 540) % 360 - 180
        if dx == 0 and dy == 0 then delta = 0 end
        local x = width / 2 + delta * pixelsPerDegree
        if x >= 0 and x <= width then
            points[#points + 1] = { marker = marker, x = x, distance = Markers.distance(player, marker), count = 0 }
        end
    end
    table.sort(points, function(a, b) return a.x < b.x end)
    local groups = {}
    for _, point in ipairs(points) do
        local group = groups[#groups]
        if group and point.x - group.right < 24 then
            group.right = point.x
            group.count = group.count + 1
            if point.distance < group.distance then
                group.marker, group.x, group.distance = point.marker, point.x, point.distance
            end
        else
            point.right = point.x
            groups[#groups + 1] = point
        end
    end
    return groups
end

function Markers.drawIcon(ui, marker, x, y, size)
    local s = marker.signature
    local definition = not s.text and MapSymbolDefinitions.getInstance():getSymbolById(s.content)
    local texture = definition and getTexture(definition:getTexturePath())
    if texture then
        ui:drawTextureScaled(texture, x, y, size, size, s.a, s.r, s.g, s.b)
    else
        ui:drawRectBorder(x + 3, y + 2, size - 6, size - 4, s.a, s.r, s.g, s.b)
        ui:drawRect(x + 6, y + 6, size - 12, 1, s.a, s.r, s.g, s.b)
        ui:drawRect(x + 6, y + 10, size - 12, 1, s.a, s.r, s.g, s.b)
    end
end

return Markers
