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
}
