package maeiro.viewpointcompass;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

import me.zed_0xff.zombie_buddy.Exposer;

public final class ClientLuaBootstrap {
    private static final String BOOTSTRAP_SCRIPT = "ViewpointCompassBootstrap.lua";
    private static final long RETRY_INTERVAL_NANOS = 1_000_000_000L;
    private static final int MAX_LOAD_ATTEMPTS = 30;
    private static boolean loadPending;
    private static long lastAttemptNanos;
    private static int loadAttempts;

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

    public static void beginLoadCycle() {
        loadPending = true;
        lastAttemptNanos = 0;
        loadAttempts = 0;
        attemptLoad();
    }

    public static void load() {
        beginLoadCycle();
    }

    public static void retryIfPending() {
        if (!loadPending) {
            return;
        }

        long now = System.nanoTime();
        if (lastAttemptNanos != 0 && now - lastAttemptNanos < RETRY_INTERVAL_NANOS) {
            return;
        }
        attemptLoad();
    }

    public static void markLuaLoaded() {
        loadPending = false;
    }

    private static void attemptLoad() {
        if (!loadPending) {
            return;
        }
        if (loadAttempts >= MAX_LOAD_ATTEMPTS) {
            loadPending = false;
            return;
        }
        loadAttempts++;
        lastAttemptNanos = System.nanoTime();
        try {
            ViewpointCompassBridge.getHeading();

            String luaDirectory = getClientLuaDirectory();
            if (luaDirectory == null) {
                return;
            }

            Path scriptPath = Paths.get(luaDirectory).resolve(BOOTSTRAP_SCRIPT);
            if (!Files.isRegularFile(scriptPath)) {
                return;
            }

            Class<?> luaManager = Class.forName("zombie.Lua.LuaManager");
            Field luaEnvironment = luaManager.getField("env");
            Field luaExposer = luaManager.getField("exposer");
            if (luaEnvironment.get(null) == null || luaExposer.get(null) == null) {
                return;
            }

            Method runLua = luaManager.getMethod("RunLua", String.class);
            if (!Modifier.isStatic(runLua.getModifiers())) {
                return;
            }
            Path executionScript = Files.createTempFile("ViewpointCompassBootstrap-", ".lua");
            try {
                Files.copy(scriptPath, executionScript, StandardCopyOption.REPLACE_EXISTING);
                runLua.invoke(null, executionScript.toString());
            } finally {
                try {
                    Files.deleteIfExists(executionScript);
                } catch (Throwable ignored) {
                }
            }
        } catch (Throwable ignored) {
        }
    }
}
