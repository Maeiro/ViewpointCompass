package maeiro.viewpointcompass;

import viewpoint.core.View;
import viewpoint.input.FreeCam;
import viewpoint.input.Look;

public final class ViewpointCompassBridgeTest {
    public static void main(String[] args) {
        View.enabled = false;
        check(ViewpointCompassBridge.getHeading() == -1.0f,
                "compass should be hidden while Viewpoint is inactive");

        View.enabled = true;
        checkHeading(-Math.PI / 2, 0, "north");
        checkHeading(0, 90, "east");
        checkHeading(Math.PI / 2, 180, "south");
        checkHeading(Math.PI, 270, "west");

        Look.yaw = 0;
        FreeCam.active = true;
        FreeCam.place = new FreeCam.Place((float) -Math.PI / 2);
        check(Math.abs(ViewpointCompassBridge.getHeading()) < 0.001f,
                "free camera heading should override player look yaw");

        System.out.println("ViewpointCompassBridgeTest: PASS");
    }

    private static void checkHeading(double yaw, float expected, String direction) {
        FreeCam.active = false;
        Look.yaw = (float) yaw;
        float actual = ViewpointCompassBridge.getHeading();
        check(Math.abs(actual - expected) < 0.001f,
                direction + " heading should map to " + expected + " degrees");
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
