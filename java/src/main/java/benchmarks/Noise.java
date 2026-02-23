package benchmarks;

import java.util.*;

public class Noise extends Benchmark {

    static class Vec2 {
        final double x, y;

        Vec2(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }

    static class Noise2DContext {
        private final Vec2[] rgradients;
        private final int[] permutations;
        private final int sizeVal;

        Noise2DContext(int size) {
            this.sizeVal = size;
            this.rgradients = new Vec2[size];
            this.permutations = new int[size];

            for (int i = 0; i < size; i++) {
                rgradients[i] = randomGradient();
                permutations[i] = i;
            }

            for (int i = 0; i < size; i++) {
                int a = Helper.nextInt(size);
                int b = Helper.nextInt(size);
                int temp = permutations[a];
                permutations[a] = permutations[b];
                permutations[b] = temp;
            }
        }

        private Vec2 randomGradient() {
            double v = Helper.nextFloat() * Math.PI * 2.0;
            return new Vec2(Math.cos(v), Math.sin(v));
        }

        private Vec2 getGradient(int x, int y) {
            int idx = permutations[x & (sizeVal - 1)] + permutations[y & (sizeVal - 1)];
            return rgradients[idx & (sizeVal - 1)];
        }

        private Vec2[][] getGradients(double x, double y) {
            double x0f = Math.floor(x);
            double y0f = Math.floor(y);
            int x0 = (int) x0f;
            int y0 = (int) y0f;

            Vec2[] gradients = {
                getGradient(x0, y0),
                getGradient(x0 + 1, y0),
                getGradient(x0, y0 + 1),
                getGradient(x0 + 1, y0 + 1)
            };

            Vec2[] origins = {
                new Vec2(x0f + 0.0, y0f + 0.0),
                new Vec2(x0f + 1.0, y0f + 0.0),
                new Vec2(x0f + 0.0, y0f + 1.0),
                new Vec2(x0f + 1.0, y0f + 1.0)
            };

            return new Vec2[][] {gradients, origins};
        }

        double get(double x, double y) {
            Vec2 p = new Vec2(x, y);
            Vec2[][] go = getGradients(x, y);
            Vec2[] gradients = go[0];
            Vec2[] origins = go[1];

            double v0 = gradient(origins[0], gradients[0], p);
            double v1 = gradient(origins[1], gradients[1], p);
            double v2 = gradient(origins[2], gradients[2], p);
            double v3 = gradient(origins[3], gradients[3], p);

            double fx = smooth(x - origins[0].x);
            double vx0 = lerp(v0, v1, fx);
            double vx1 = lerp(v2, v3, fx);

            double fy = smooth(y - origins[0].y);
            return lerp(vx0, vx1, fy);
        }

        private double gradient(Vec2 orig, Vec2 grad, Vec2 p) {
            Vec2 sp = new Vec2(p.x - orig.x, p.y - orig.y);
            return grad.x * sp.x + grad.y * sp.y;
        }

        private double lerp(double a, double b, double v) {
            return a * (1.0 - v) + b * v;
        }

        private double smooth(double v) {
            return v * v * (3.0 - 2.0 * v);
        }
    }

    private long sizeVal;
    private long resultVal;
    private Noise2DContext n2d;

    public Noise() {
        sizeVal = configVal("size");
        resultVal = 0L;
        n2d = new Noise2DContext((int) sizeVal);
    }

    @Override
    public String name() {
        return "Etc::Noise";
    }

    private static final char[] SYM = {' ', '░', '▒', '▓', '█', '█'};

    @Override
    public void run(int iterationId) {
        for (long y = 0; y < sizeVal; y++) {
            for (long x = 0; x < sizeVal; x++) {
                double v = n2d.get(x * 0.1, (y + (iterationId * 128)) * 0.1) * 0.5 + 0.5;
                int idx = (int) (v / 0.2);
                if (idx >= 6) idx = 5;
                resultVal += SYM[idx];
            }
        }
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}