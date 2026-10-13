package maeiro.viewpointcompass;

public final class MapMarkerBridgeTest {
    public static void main(String[] args) throws Exception {
        Class<?> collectionClass = Class.forName("zombie.worldMap.symbols.WorldMapSymbols");
        Object collection = collectionClass.getConstructor().newInstance();
        Object first = texture(collection, 10, 20, 0.2f);
        Object second = texture(collection, 30, 40, 1);
        check(MapMarkerBridge.getCount(collection) == 2, "count");
        check(MapMarkerBridge.getSymbol(collection, 0) == first, "raw identity");
        check(MapMarkerBridge.getSymbol(collection, 1) == second, "same icon, different identity");
        check(MapMarkerBridge.getNumber(first, "x") == 10, "position");
        check(Math.abs(MapMarkerBridge.getNumber(first, "r") - 0.2) < 0.001, "color");
        check(MapMarkerBridge.getContent(first).equals("test"), "icon identifier");
        long generation = MapMarkerBridge.getGeneration(collection, first);
        collectionClass.getMethod("removeSymbolByIndex", int.class).invoke(collection, 0);
        check(MapMarkerBridge.getSymbol(collection, 0) == second, "identity after removal");
        check(MapMarkerBridge.getGeneration(collection, first) != generation, "removed objects cannot inherit identity");
        second.getClass().getMethod("setUserDefined", boolean.class).invoke(second, true);
        long retainedGeneration = MapMarkerBridge.getGeneration(collection, second);
        collectionClass.getMethod("clearDefaultAnnotations").invoke(collection);
        check(MapMarkerBridge.getCount(collection) == 1, "default cleanup keeps user annotation");
        check(MapMarkerBridge.getGeneration(collection, second) == retainedGeneration,
                "default cleanup preserves retained identity");

        Object note = collectionClass.getMethod("addUntranslatedText", String.class, String.class,
                float.class, float.class, float.class, float.class, float.class, float.class)
                .invoke(collection, "MapLabel_Test", "test", 5f, 6f, 1f, 1f, 1f, 1f);
        check(MapMarkerBridge.isText(note), "note type");
        check(MapMarkerBridge.getContent(note).equals("MapLabel_Test"), "note key");
        note.getClass().getMethod("setTranslatedText", String.class).invoke(note, "My base");
        check(MapMarkerBridge.getContent(note).equals("My base"), "literal note content");
        check(MapMarkerBridge.getStyle(note).contains(":false:"), "literal note appearance");
        for (String field : new String[] { "x", "y", "r", "g", "b", "a", "scale", "rotation",
                "anchorX", "anchorY", "minZoom", "maxZoom" }) {
            MapMarkerBridge.getNumber(note, field);
        }
        System.out.println("MapMarkerBridgeTest: PASS (installed game classes)");
    }

    private static Object texture(Object collection, float x, float y, float red) throws Exception {
        Class<?> baseClass = Class.forName("zombie.worldMap.symbols.WorldMapBaseSymbol");
        Class<?> textureClass = Class.forName("zombie.worldMap.symbols.WorldMapTextureSymbol");
        Object symbol = textureClass.getConstructor(collection.getClass()).newInstance(collection);
        java.lang.reflect.Field id = textureClass.getDeclaredField("symbolId");
        id.setAccessible(true);
        id.set(symbol, "test");
        baseClass.getMethod("setPosition", float.class, float.class).invoke(symbol, x, y);
        baseClass.getMethod("setRGBA", float.class, float.class, float.class, float.class)
                .invoke(symbol, red, 0.3f, 0.4f, 1f);
        collection.getClass().getMethod("addSymbol", baseClass).invoke(collection, symbol);
        return symbol;
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
