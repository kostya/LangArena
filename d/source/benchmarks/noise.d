module benchmarks.noise;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.random;
import std.typecons;
import benchmark;
import helper;

class Noise : Benchmark
{
private:
    static struct Vec2
    {
        double x, y;

        this(double x, double y)
        {
            this.x = x;
            this.y = y;
        }
    }

    class Noise2DContext
    {
    private:
        Vec2[] rgradients;
        int[] permutations;
        int sizeVal;

        static Vec2 randomGradient()
        {
            double v = Helper.nextFloat() * PI * 2.0;
            return Vec2(cos(v), sin(v));
        }

        static double lerp(double a, double b, double v)
        {
            return a * (1.0 - v) + b * v;
        }

        static double smooth(double v)
        {
            return v * v * (3.0 - 2.0 * v);
        }

        static double gradient(const Vec2 orig, const Vec2 grad, const Vec2 p)
        {
            Vec2 sp = Vec2(p.x - orig.x, p.y - orig.y);
            return grad.x * sp.x + grad.y * sp.y;
        }

    public:
        this(int size)
        {
            sizeVal = size;
            rgradients.length = size;
            permutations.length = size;

            foreach (i; 0 .. size)
            {
                rgradients[i] = randomGradient();
                permutations[i] = i;
            }

            foreach (i; 0 .. size)
            {
                int a = Helper.nextInt(size);
                int b = Helper.nextInt(size);
                swap(permutations[a], permutations[b]);
            }
        }

        Vec2 getGradient(int x, int y)
        {
            int idx = permutations[x & (sizeVal - 1)] + permutations[y & (sizeVal - 1)];
            return rgradients[idx & (sizeVal - 1)];
        }

        Tuple!(Vec2[4], Vec2[4]) getGradients(double x, double y)
        {
            double x0f = floor(x);
            double y0f = floor(y);
            int x0 = cast(int) x0f;
            int y0 = cast(int) y0f;
            int x1 = x0 + 1;
            int y1 = y0 + 1;

            Vec2[4] gradients = [
                getGradient(x0, y0), getGradient(x1, y0), getGradient(x0,
                        y1), getGradient(x1, y1)
            ];

            Vec2[4] origins = [
                Vec2(x0f + 0.0, y0f + 0.0), Vec2(x0f + 1.0, y0f + 0.0),
                Vec2(x0f + 0.0, y0f + 1.0), Vec2(x0f + 1.0, y0f + 1.0)
            ];

            return tuple(gradients, origins);
        }

        double get(double x, double y)
        {
            Vec2 p = Vec2(x, y);
            auto result = getGradients(x, y);
            auto gradients = result[0];
            auto origins = result[1];

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
    }

    enum dchar[6] SYM = [' ', '░', '▒', '▓', '█', '█'];

protected:
    int sizeVal;
    uint resultVal;
    Noise2DContext n2d;

    override string className() const
    {
        return "Noise";
    }

public:
    this()
    {
        sizeVal = configVal("size");
        resultVal = 0;
        n2d = new Noise2DContext(sizeVal);
    }

    override void run(int iterationId)
    {
        for (int y = 0; y < sizeVal; y++)
        {
            for (int x = 0; x < sizeVal; x++)
            {
                double v = n2d.get(x * 0.1, (y + (iterationId * 128)) * 0.1) * 0.5 + 0.5;
                int idx = cast(int)(v / 0.2);
                if (idx >= 6)
                    idx = 5;
                resultVal += cast(uint)(SYM[idx]);
            }
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
