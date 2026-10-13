package maeiro.viewpointcompass;

import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;
import java.util.WeakHashMap;

import me.zed_0xff.zombie_buddy.Exposer;

public final class MapMarkerBridge {
    private static final Map<String, Field> fields = new HashMap<>();
    private static final Map<Object, Long> generations = new WeakHashMap<>();
    private static Object observedCollection;
    private static long nextGeneration;

    private MapMarkerBridge() {
    }

    static void initialize() {
        Exposer.exposeClass(MapMarkerBridge.class, "ViewpointCompassMap");
    }

    public static Object getCollection() throws ReflectiveOperationException {
        Object item = Class.forName("zombie.inventory.types.MapItem")
                .getMethod("getSingleton").invoke(null);
        return item == null ? null : item.getClass().getMethod("getSymbols").invoke(item);
    }

    public static int getCount(Object collection) throws ReflectiveOperationException {
        return (Integer) collection.getClass().getMethod("getSymbolCount").invoke(collection);
    }

    public static Object getSymbol(Object collection, int index) throws ReflectiveOperationException {
        observe(collection);
        return collection.getClass().getMethod("getSymbolByIndex", int.class).invoke(collection, index);
    }

    public static long getGeneration(Object collection, Object symbol) throws ReflectiveOperationException {
        observe(collection);
        return generations.computeIfAbsent(symbol, ignored -> ++nextGeneration);
    }

    private static void observe(Object collection) throws ReflectiveOperationException {
        if (observedCollection == collection) return;
        Class<?> listenerClass = Class.forName("zombie.worldMap.symbols.IWorldMapSymbolListener");
        Object listener = Proxy.newProxyInstance(listenerClass.getClassLoader(), new Class<?>[] { listenerClass },
                (proxy, method, args) -> {
                    switch (method.getName()) {
                        case "onBeforeRemove" -> generations.remove(args[0]);
                        case "onBeforeClear" -> generations.clear();
                        case "equals" -> { return proxy == args[0]; }
                        case "hashCode" -> { return System.identityHashCode(proxy); }
                        case "toString" -> { return "ViewpointCompassMapListener"; }
                        default -> { }
                    }
                    return null;
                });
        collection.getClass().getMethod("addListener", listenerClass).invoke(collection, listener);
        observedCollection = collection;
    }

    public static double getNumber(Object symbol, String name) throws ReflectiveOperationException {
        Field field = fields.get(name);
        if (field == null) {
            field = Class.forName("zombie.worldMap.symbols.WorldMapBaseSymbol").getDeclaredField(name);
            field.setAccessible(true);
            fields.put(name, field);
        }
        return ((Number) field.get(symbol)).doubleValue();
    }

    public static boolean isText(Object symbol) {
        return symbol.getClass().getSimpleName().equals("WorldMapTextSymbol");
    }

    public static String getContent(Object symbol) throws ReflectiveOperationException {
        if (!isText(symbol)) return (String) symbol.getClass().getMethod("getSymbolID").invoke(symbol);
        String untranslated = (String) symbol.getClass().getMethod("getUntranslatedText").invoke(symbol);
        return untranslated != null ? untranslated
                : (String) symbol.getClass().getMethod("getTranslatedText").invoke(symbol);
    }

    public static String getLabel(Object symbol) throws ReflectiveOperationException {
        return isText(symbol) ? (String) symbol.getClass().getMethod("getTranslatedText").invoke(symbol)
                : getContent(symbol);
    }

    public static String getStyle(Object symbol) throws ReflectiveOperationException {
        String textStyle = "";
        if (isText(symbol)) {
            textStyle = symbol.getClass().getMethod("getLayerID").invoke(symbol) + ":"
                    + (symbol.getClass().getMethod("getUntranslatedText").invoke(symbol) != null);
        }
        return textStyle + ":" + symbol.getClass().getMethod("isMatchPerspective").invoke(symbol)
                + ":" + symbol.getClass().getMethod("isApplyZoom").invoke(symbol);
    }
}
