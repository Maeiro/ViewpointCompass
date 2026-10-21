from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
client = root / "42/media/lua/client"
server = root / "42/media/lua/server"
lua.globals().package.path = client.as_posix() + "/?.lua;" + server.as_posix() + "/?.lua;" + lua.globals().package.path
for path in [*client.rglob("*.lua"), *server.rglob("*.lua")]:
    lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8"))
for path in (root / "42/media/lua/shared/Translate").rglob("*.json"):
    json.loads(path.read_text(encoding="utf-8"))
sandbox_options = (root / "42/media/sandbox-options.txt").read_text(encoding="utf-8")
assert sandbox_options.startswith("VERSION = 1,")
policy_names = [
    "RequireCompassItem", "AllowMapWaypoints", "AllowFactionPlayers",
    "MaxFactionPlayerRange", "ShowFactionPlayerDistance",
]
for option in policy_names:
    assert f"option ViewpointCompass.{option}" in sandbox_options
for locale in ("EN", "PTBR", "CN", "CH"):
    sandbox_translation = json.loads(
        (root / f"42/media/lua/shared/Translate/{locale}/Sandbox.json").read_text(encoding="utf-8")
    )
    assert all(f"Sandbox_ViewpointCompass_{option}" in sandbox_translation for option in policy_names)
lua.execute((root / "testsrc/markers_test.lua").read_text(encoding="utf-8"))
lua.execute((root / "testsrc/map_integration_test.lua").read_text(encoding="utf-8"))
lua.execute((root / "testsrc/marker_window_test.lua").read_text(encoding="utf-8"))
lua.execute((root / "testsrc/faction_players_test.lua").read_text(encoding="utf-8"))
lua.execute((root / "testsrc/server_faction_players_test.lua").read_text(encoding="utf-8"))
print("Lua 5.1 syntax, translation JSON, and faction-player tests: PASS")
