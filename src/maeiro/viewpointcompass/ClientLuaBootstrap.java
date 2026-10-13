package maeiro.viewpointcompass;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import me.zed_0xff.zombie_buddy.Exposer;

public final class ClientLuaBootstrap {
    private static final String BOOTSTRAP_SCRIPT = "ViewpointCompassBootstrap.lua";

    static {
        Exposer.exposeClass(ClientLuaBootstrap.class, "ViewpointCompassClient");
    }

    private ClientLuaBootstrap() {
    }

    public static String getClientLuaDirectory() {
        try {
            URI jarUri = ClientLuaBootstrap.class.getProtectionDomain().getCodeSource().getLocation().toURI();
            Path jarPath = Paths.get(jarUri);
            Path mediaDirectory = jarPath.getParent().getParent().getParent();
            if (mediaDirectory == null) {
                return null;
            }
            return mediaDirectory.resolve("lua").resolve("client").normalize().toString();
        } catch (Throwable ignored) {
            return null;
        }
    }

    public static void load() {
        try {
            ViewpointCompassBridge.getHeading();

            String luaDirectory = getClientLuaDirectory();
            if (luaDirectory == null) {
                report("Could not locate the client Lua directory.");
                return;
            }

            Path scriptPath = Paths.get(luaDirectory).resolve(BOOTSTRAP_SCRIPT);
            if (!Files.isRegularFile(scriptPath)) {
                report("Client Lua bootstrap script was not found.");
                return;
            }

            Class<?> luaManager = Class.forName("zombie.Lua.LuaManager");
            Method runLua = luaManager.getMethod("RunLua", String.class);
            if (!Modifier.isStatic(runLua.getModifiers())) {
                report("LuaManager.RunLua is not static.");
                return;
            }
            runLua.invoke(null, scriptPath.toString());
        } catch (Throwable error) {
            Throwable cause = error instanceof InvocationTargetException && error.getCause() != null
                    ? error.getCause()
                    : error;
            report("Could not load client Lua: " + cause);
        }
    }

    private static void report(String message) {
        System.err.println("[Viewpoint Compass] " + message);
    }
}
