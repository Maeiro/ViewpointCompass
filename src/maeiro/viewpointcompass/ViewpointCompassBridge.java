package maeiro.viewpointcompass;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import me.zed_0xff.zombie_buddy.Exposer;

public final class ViewpointCompassBridge {
    private static volatile Field viewEnabled;
    private static volatile Field lookYaw;
    private static volatile Field freeCameraActive;
    private static volatile Field freeCameraPlace;
    private static volatile Method freeCameraYaw;

    static {
        Exposer.exposeClass(ViewpointCompassBridge.class, "ViewpointCompass");
    }

    private ViewpointCompassBridge() {
    }

    public static float getHeading() {
        try {
            Field enabledField = viewEnabled;
            if (enabledField == null) {
                enabledField = field("viewpoint.core.View", "enabled");
                viewEnabled = enabledField;
            }
            if (enabledField == null || !enabledField.getBoolean(null)) {
                return -1.0f;
            }

            Field yawField = lookYaw;
            if (yawField == null) {
                yawField = field("viewpoint.input.Look", "yaw");
                lookYaw = yawField;
            }
            if (yawField == null) {
                return -1.0f;
            }
            float yaw = yawField.getFloat(null);

            Field activeField = freeCameraActive;
            if (activeField == null) {
                activeField = field("viewpoint.input.FreeCam", "active");
                freeCameraActive = activeField;
            }
            Field placeField = freeCameraPlace;
            if (placeField == null) {
                placeField = field("viewpoint.input.FreeCam", "place");
                freeCameraPlace = placeField;
            }
            if (activeField != null && activeField.getBoolean(null) && placeField != null) {
                Object place = placeField.get(null);
                if (place != null) {
                    Method yawMethod = freeCameraYaw;
                    if (yawMethod == null) {
                        yawMethod = place.getClass().getDeclaredMethod("yaw");
                        yawMethod.setAccessible(true);
                        freeCameraYaw = yawMethod;
                    }
                    Object placeYaw = yawMethod.invoke(place);
                    if (placeYaw instanceof Number number) {
                        yaw = number.floatValue();
                    }
                }
            }

            return headingFromYaw(yaw);
        } catch (Throwable ignored) {
            return -1.0f;
        }
    }

    static float headingFromYaw(float yaw) {
        float heading = (float) Math.toDegrees(yaw) + 90.0f;
        heading %= 360.0f;
        return heading < 0 ? heading + 360.0f : heading;
    }

    private static Field field(String className, String fieldName) {
        try {
            Field field = Class.forName(className).getDeclaredField(fieldName);
            field.setAccessible(true);
            return field;
        } catch (Throwable ignored) {
            return null;
        }
    }
}
