package viewpoint.input;

public final class FreeCam {
    public static volatile boolean active;
    public static volatile Place place;

    public static final class Place {
        private final float yaw;

        public Place(float yaw) {
            this.yaw = yaw;
        }

        public float yaw() {
            return yaw;
        }
    }
}
