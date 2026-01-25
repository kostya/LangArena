package benchmarks;

import java.util.*;

public class Noise extends Benchmark {
    private static final int SIZE = 64;
    private static final char[] SYM = {' ', '░', '▒', '▓', '█', '█'};
    
    static class Vec2 {
        final double x, y;
        
        Vec2(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }
    
    static class Noise2DContext {
        private final Vec2[] rgradients = new Vec2[SIZE];
        private final int[] permutations = new int[SIZE];
        
        Noise2DContext() {
            // Инициализация градиентов
            for (int i = 0; i < SIZE; i++) {
                rgradients[i] = randomGradient();
            }
            
            // Инициализация перестановок
            for (int i = 0; i < SIZE; i++) {
                permutations[i] = i;
            }
            
            // Перемешивание
            for (int i = 0; i < SIZE; i++) {
                int a = Helper.nextInt(SIZE);
                int b = Helper.nextInt(SIZE);
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
            int idx = permutations[x & (SIZE - 1)] + permutations[y & (SIZE - 1)];
            return rgradients[idx & (SIZE - 1)];
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
            
            return new Vec2[][]{gradients, origins};
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
    
    private int n;
    private long result;
    
    public Noise() {
        n = getIterations();
    }
    
    private long noise() {
        double[][] pixels = new double[SIZE][SIZE];
        Noise2DContext n2d = new Noise2DContext();
        
        for (int i = 0; i < 100; i++) {
            for (int y = 0; y < SIZE; y++) {
                for (int x = 0; x < SIZE; x++) {
                    double v = n2d.get(x * 0.1, (y + (i * 128)) * 0.1) * 0.5 + 0.5;
                    pixels[y][x] = v;
                }
            }
        }
        
        long res = 0L;
        
        for (int y = 0; y < SIZE; y++) {
            for (int x = 0; x < SIZE; x++) {
                double v = pixels[y][x];
                int idx = (int) (v / 0.2);
                if (idx < 0) idx = 0;
                if (idx >= SYM.length) idx = SYM.length - 1;
                res += SYM[idx];
            }
        }
        
        return res;
    }
    
    @Override
    public void run() {
        for (int i = 0; i < n; i++) {
            long v = noise();
            result = (result + v);
        }
    }
    
    @Override
    public long getResult() {
        return result;
    }
}