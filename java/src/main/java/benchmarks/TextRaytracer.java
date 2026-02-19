package benchmarks;

import java.util.*;

public class TextRaytracer extends Benchmark {

    static class Vector {
        final double x, y, z;

        Vector(double x, double y, double z) {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        Vector scale(double s) {
            return new Vector(x * s, y * s, z * s);
        }

        Vector add(Vector other) {
            return new Vector(x + other.x, y + other.y, z + other.z);
        }

        Vector sub(Vector other) {
            return new Vector(x - other.x, y - other.y, z - other.z);
        }

        double dot(Vector other) {
            return x * other.x + y * other.y + z * other.z;
        }

        double magnitude() {
            return Math.sqrt(dot(this));
        }

        Vector normalize() {
            return scale(1.0 / magnitude());
        }
    }

    static class Ray {
        final Vector orig, dir;

        Ray(Vector orig, Vector dir) {
            this.orig = orig;
            this.dir = dir;
        }
    }

    static class Color {
        final double r, g, b;

        Color(double r, double g, double b) {
            this.r = r;
            this.g = g;
            this.b = b;
        }

        Color scale(double s) {
            return new Color(r * s, g * s, b * s);
        }

        Color add(Color other) {
            return new Color(r + other.r, g + other.g, b + other.b);
        }
    }

    static class Sphere {
        final Vector center;
        final double radius;
        final Color color;

        Sphere(Vector center, double radius, Color color) {
            this.center = center;
            this.radius = radius;
            this.color = color;
        }

        Vector getNormal(Vector pt) {
            return pt.sub(center).normalize();
        }
    }

    static class Light {
        final Vector position;
        final Color color;

        Light(Vector position, Color color) {
            this.position = position;
            this.color = color;
        }
    }

    static class Hit {
        final Sphere obj;
        final double value;

        Hit(Sphere obj, double value) {
            this.obj = obj;
            this.value = value;
        }
    }

    private static final Color WHITE = new Color(1.0, 1.0, 1.0);
    private static final Color RED = new Color(1.0, 0.0, 0.0);
    private static final Color GREEN = new Color(0.0, 1.0, 0.0);
    private static final Color BLUE = new Color(0.0, 0.0, 1.0);
    private static final Light LIGHT1 = new Light(new Vector(0.7, -1.0, 1.7), WHITE);
    private static final char[] LUT = {'.', '-', '+', '*', 'X', 'M'};

    private static final List<Sphere> SCENE = Arrays.asList(
            new Sphere(new Vector(-1.0, 0.0, 3.0), 0.3, RED),
            new Sphere(new Vector(0.0, 0.0, 3.0), 0.8, GREEN),
            new Sphere(new Vector(1.0, 0.0, 3.0), 0.4, BLUE)
        );

    private int w, h;
    private long resultVal;

    public TextRaytracer() {
        w = (int) configVal("w");
        h = (int) configVal("h");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "TextRaytracer";
    }

    private int shadePixel(Ray ray, Sphere obj, double tval) {
        Vector pi = ray.orig.add(ray.dir.scale(tval));
        Color color = diffuseShading(pi, obj, LIGHT1);
        double col = (color.r + color.g + color.b) / 3.0;
        return (int) (col * 6.0);
    }

    private Double intersectSphere(Ray ray, Vector center, double radius) {
        Vector l = center.sub(ray.orig);
        double tca = l.dot(ray.dir);
        if (tca < 0.0) return null;

        double d2 = l.dot(l) - tca * tca;
        double r2 = radius * radius;
        if (d2 > r2) return null;

        double thc = Math.sqrt(r2 - d2);
        double t0 = tca - thc;
        if (t0 > 10000) return null;

        return t0;
    }

    private double clamp(double x, double a, double b) {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }

    private Color diffuseShading(Vector pi, Sphere obj, Light light) {
        Vector n = obj.getNormal(pi);
        double lam1 = light.position.sub(pi).normalize().dot(n);
        double lam2 = clamp(lam1, 0.0, 1.0);
        return light.color.scale(lam2 * 0.5).add(obj.color.scale(0.3));
    }

    @Override
    public void run(int iterationId) {
        double fw = w;
        double fh = h;

        for (int j = 0; j < h; j++) {
            for (int i = 0; i < w; i++) {
                double fi = i;
                double fj = j;

                Ray ray = new Ray(
                    new Vector(0.0, 0.0, 0.0),
                    new Vector((fi - fw / 2.0) / fw,
                               (fj - fh / 2.0) / fh, 1.0).normalize()
                );

                Hit hit = null;

                for (Sphere obj : SCENE) {
                    Double ret = intersectSphere(ray, obj.center, obj.radius);
                    if (ret != null) {
                        hit = new Hit(obj, ret);
                        break;
                    }
                }

                char pixel;
                if (hit != null) {
                    int shade = shadePixel(ray, hit.obj, hit.value);
                    if (shade < 0) shade = 0;
                    if (shade >= LUT.length) shade = LUT.length - 1;
                    pixel = LUT[shade];
                } else {
                    pixel = ' ';
                }

                resultVal += pixel;
            }
        }
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}