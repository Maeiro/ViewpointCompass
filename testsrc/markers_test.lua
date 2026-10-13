local Markers = require "ViewpointCompass/Markers"
local clock = 0
function getTimestampMs() return clock end
local collection = {}
ViewpointCompassMap = {
    getCollection = function() return collection end,
    getCount = function(c) return #c end,
    getSymbol = function(c, index) return c[index + 1] end,
    isText = function(s) return s.text end,
    getContent = function(s) return s.content end,
    getLabel = function(s) return s.content end,
    getStyle = function(s) return s.style or "default" end,
    getNumber = function(s, key) return s[key] end,
    getGeneration = function(c, s) return s.generation or 1 end,
}
local function symbol(x, y, content, text)
    return { x = x, y = y, content = content or "house", text = text or false,
        r = 0.2, g = 0.3, b = 0.4, a = 1, scale = 1, rotation = 0,
        anchorX = 0.5, anchorY = 0.5, minZoom = 0, maxZoom = 24 }
end
local function player(data)
    return { data = data or {}, getModData = function(self) return self.data end,
        getX = function() return 0 end, getY = function() return 0 end }
end
local function check(value, message) assert(value, message) end
local p = player()
local before, a, b, note = symbol(1, 1), symbol(0, -25), symbol(10, -40), symbol(4, 5, "Base", true)
collection = { before, a, b, note }
check(#Markers.refresh(p, true).markers == 0, "no automatic selections")
Markers.add(p, 1); Markers.add(p, 1); Markers.add(p, 2); Markers.add(p, 3)
local state = Markers.refresh(p, true)
check(#state.markers == 3, "duplicates prevented")
check(state.markers[1].signature.r == 0.2, "color retained")
check(Markers.name(state.markers[3]) == "Base", "note name")
Markers.rename(p, state.markers[3], "  Home  ")
check(Markers.name(state.markers[3]) == "Home" and note.content == "Base", "nickname only")
table.remove(collection, 1)
Markers.refresh(p, true)
check(state.markers[1].symbol == a and state.markers[1].index == 0, "earlier deletion shifts index, not target")
a.x = 12; a.r = 1; note.content = "Edited note"
Markers.refresh(p, true)
check(state.markers[1].signature.x == 12 and state.markers[1].signature.r == 1, "move and color edit")
check(Markers.name(state.markers[3]) == "Home", "nickname survives note edit")
local saved = p.data
Markers.states[p] = nil
state = Markers.refresh(p, true)
check(#state.markers == 3 and state.markers[1].symbol == a, "restore before map opened")
check(Markers.name(state.markers[3]) == "Home", "saved nickname")
check(#Markers.refresh(player(), true).markers == 0, "character/save isolation")
table.remove(collection, 2)
Markers.refresh(p, true)
check(#state.markers == 2 and state.markers[2].symbol == note, "source deletion")
Markers.remove(p, state.markers[1])
check(#collection == 2 and #state.markers == 1, "remove keeps map symbol")
Markers.remove(p)
check(#collection == 2 and #state.markers == 0, "remove all keeps annotations")
collection = { symbol(20, 20), symbol(20, 20) }
Markers.add(p, 0)
Markers.states[p] = nil
check(#Markers.refresh(p, true).markers == 0, "ambiguous signatures never retarget")
collection = { symbol(11, 12) }
Markers.add(p, 0)
Markers.states[p] = nil
collection = { symbol(22, 24) }
check(#Markers.refresh(p, true).markers == 0, "missing signature never retargets saved index")
collection = { symbol(0, -25) }
Markers.add(p, 0)
state = Markers.refresh(p, true)
local revision = state.revision
Markers.refresh(p, true)
check(state.revision == revision, "unchanged refresh does not rewrite persistence")
collection[1].x = 99
clock = 100
Markers.refresh(p)
check(state.markers[1].signature.x == 0, "250ms refresh throttle")
clock = 250
Markers.refresh(p)
check(state.markers[1].signature.x == 99, "refresh after interval")
collection[1].generation = 2
Markers.refresh(p, true)
check(#state.markers == 0, "recycled raw object is not a new destination")

local function point(x, y) return { signature = symbol(x, y) } end
for _, test in ipairs({ { 0, -25, 0 }, { 25, 0, 90 }, { 0, 25, 180 }, { -25, 0, 270 } }) do
    local projected = Markers.project(p, { point(test[1], test[2]) }, test[3], 520, 6)
    check(#projected == 1 and math.abs(projected[1].x - 260) < 0.001, "cardinal bearing")
    check(projected[1].distance == 25, "horizontal distance")
end
local north = point(0, -25)
check(math.abs(Markers.project(p, { north }, 359, 520, 6)[1].x - 266) < 0.001, "359/0 wrapping")
check(#Markers.project(p, { north }, 180, 520, 6) == 0, "outside ribbon hidden")
check(#Markers.project(p, { point(0, 0) }, 180, 520, 6) == 1, "zero distance remains visible")
local grouped = Markers.project(p, { point(0, -50), point(0, -20), point(0, -30) }, 0, 520, 6)
check(#grouped == 1 and grouped[1].distance == 20 and grouped[1].count == 2, "nearest +N grouping")
local adjacent = Markers.project(p, { point(0, -50), point(5, -50) }, 0, 520, 6)
check(#adjacent == 2, "separated icons stay individual")
print("markers_test: PASS")
local above = Markers.layout(1, true, 1)
local inside = Markers.layout(2, true, 1)
local below = Markers.layout(3, true, 1)
assert(above.rulerY == 42 and above.markerY == 0 and above.height == 84)
assert(inside.rulerY == 0 and inside.markerY == 0 and inside.height == 42 and inside.inside)
assert(below.rulerY == 0 and below.markerY == 42 and below.height == 84)
assert(Markers.layout(1, false, 3).height == 42, "hidden markers reserve no space")
assert(Markers.layout(1, true, 0).rulerY == 0, "empty selection keeps ruler at top")
assert(Markers.layout(99, true, 1).rulerY == 42, "invalid position defaults above")
print("marker_layout_test: PASS")
