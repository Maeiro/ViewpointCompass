local luaDirectory = ViewpointCompassClient and ViewpointCompassClient.getClientLuaDirectory()
if not luaDirectory or not package or not package.path then return end

luaDirectory = tostring(luaDirectory):gsub("\\", "/")
package.path = luaDirectory .. "/?.lua;" .. luaDirectory .. "/?/?.lua;" .. package.path
require "ViewpointCompass"
