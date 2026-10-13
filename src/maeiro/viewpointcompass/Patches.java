package maeiro.viewpointcompass;

import me.zed_0xff.zombie_buddy.Patch;

public final class Patches {
    private Patches() {
    }

    @Patch(className = "viewpoint.FP", methodName = "toggle", warmUp = true)
    public static class ExposeCompassBridge {
        @Patch.OnEnter
        public static void enter() {
            ViewpointCompassBridge.getHeading();
        }
    }

    @Patch(className = "zombie.gameStates.MainScreenState", methodName = "enter", warmUp = true)
    public static class LoadClientLuaAtMainScreen {
        @Patch.OnExit
        public static void exit() {
            ClientLuaBootstrap.load();
        }
    }

    @Patch(className = "zombie.gameStates.IngameState", methodName = "enter", warmUp = true)
    public static class LoadClientLuaOnWorldEnter {
        @Patch.OnExit
        public static void exit() {
            ClientLuaBootstrap.load();
        }
    }
}
