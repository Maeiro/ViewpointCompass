# Viewpoint Compass

A customizable, camera-aligned compass ribbon for Project Zomboid, showing your heading and localized direction labels while Project Viewpoint is active.

## Steam Workshop

[Subscribe to Viewpoint Compass](https://steamcommunity.com/sharedfiles/filedetails/?id=3815014026) (Workshop ID: `3815014026`).

## Features

- Live camera heading in degrees and cardinal direction.
- Five-degree ticks and fifteen-degree labels.
- Cardinal and intercardinal labels replace degree numbers at their bearings.
- Choose direction labels in English, Brazilian Portuguese, Chinese, Russian, Spanish, French, German, or Japanese; Chinese and Japanese clients use native characters, with pinyin/romaji elsewhere.
- The in-game interface, Mod Options, and map-marker tools are localized in Simplified and Traditional Chinese.
- Adjust the compass width and direction-label color; the default color is `#DEB26E`.
- Renders behind game windows such as the inventory.
- Follows Viewpoint's free-look camera.
- Enabled by default and configurable through Mod Options.
- Client-side multiplayer support: each player installs the mod locally; the server does not need to enable it.
- Optionally require the vanilla Compass item to be carried (disabled by default).
- Hidden automatically while Viewpoint is inactive.
- Opt-in destinations from symbols and notes on the main world map (M), with their colors, camera-relative icons and distance in meters (one tile = one meter).
- Add to Compass selects an existing annotation; Esc or right click cancels. No annotations are selected automatically.
- Compass Markers provides a scrollable list with names, distances and coordinates: rename, locate on the map, remove one, or remove all with confirmation. Removing destinations does not erase map annotations.
- Markers follow map edits and disappear when their source is deleted; reaching a destination does not remove it.
- Nearby ribbon icons are grouped within 24 pixels, showing the nearest destination and a count of the remaining points.
- Selections and custom names persist per character/save, even before opening the map. Ambiguous or missing annotations are not restored to a different destination.
- Show map markers is enabled by default; disabling it preserves selections. Paper maps are not supported.
- Place map markers above, inside (default), or below the compass. Inside and below keep the ruler near the top edge; no marker band is reserved when the selection is empty. Inside markers have an optional background, disabled by default. Existing position preferences are preserved.

## Testing map markers

1. Open M, choose Add to Compass, and click a symbol or note. Repeat the same selection: only one destination should exist. Test Esc and right-click cancellation.
2. Use Compass Markers to rename, locate and remove destinations. Remove All requires confirmation and keeps the original annotations.
3. Move, edit and delete selected annotations. Delete an earlier unselected annotation: other destinations must retain their identities.
4. Reload the save and check destinations before opening M. Another character/save must have its own list.
5. Test north/east/south/west, 359°/0°, free-look, vehicles, overlapping destinations and standing at a destination (0m).
6. Check list scrolling and closing, Show map markers, inventory scrolling and the original map tools.

## Requirements

- Project Viewpoint.
- ZombieBuddy 2.3.0 or newer.
- Project Zomboid Build 42.21.
- In multiplayer, install the mod on each client that wants the compass. Do not add it to the server's mod list.

## How client-side multiplayer works

Project Zomboid rebuilds the client's Lua environment when it connects to a server. That environment normally contains Lua from the server's active mod list, so a client-only mod cannot rely on its usual `require` calls after the connection reload. Viewpoint Compass restores its own client code after that reset:

1. The locally installed `42/media/java/client/ViewpointCompass.jar` is loaded by the client's mod loader. Its ZombieBuddy patches run when the main menu and in-game states enter. The in-game update hook retries the bootstrap once per second, up to 30 times, in case Lua is not ready yet.
2. Once `LuaManager.env` and `LuaManager.exposer` are available, Java runs `ViewpointCompassBootstrap.lua` from the same local mod installation. It uses `getModFileReader("ViewpointCompass", ...)` to read the mod's files by mod ID, then compiles and executes those Lua chunks in dependency order. This bypasses the server's mod list while still using the client's installed copy.
3. The bootstrap restores the Java bridge globals (`ViewpointCompassClient`, `ViewpointCompass`, and `ViewpointCompassMap`) from ZombieBuddy's `maeiro.viewpointcompass` package tables. ZombieBuddy's normal exposure pass can remove those short aliases after a Lua reload; calling its global re-exposure pass again would erase them again.
4. After the compass Lua module finishes initialization, it marks itself loaded. Java then stops retrying until the next load cycle. Single-player and other local loads continue to use the regular Lua `require` path.

This is client-only because the UI, camera heading, map-marker selection, and saved marker preferences are all read or drawn by the local player. The server does not need the Compass mod or its Java/Lua files. Each player who wants the compass must install and enable it locally, along with Project Viewpoint and ZombieBuddy, which provide the camera and Java patch APIs it uses.
