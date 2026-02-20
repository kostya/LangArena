module benchmarks.textraytracer;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.typecons;
import benchmark;
import helper;

class TextRaytracer : Benchmark
{
private:
    static struct Vector
    {
        double x, y, z;

        this(double x, double y, double z)
        {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        Vector opBinary(string op : "*")(double s) const
        {
            return Vector(x * s, y * s, z * s);
        }

        Vector opBinary(string op : "+")(const Vector other) const
        {
            return Vector(x + other.x, y + other.y, z + other.z);
        }

        Vector opBinary(string op : "-")(const Vector other) const
        {
            return Vector(x - other.x, y - other.y, z - other.z);
        }

        double dot(const Vector other) const
        {
            return x * other.x + y * other.y + z * other.z;
        }

        double magnitude() const
        {
            return sqrt(dot(this));
        }

        Vector normalize() const
        {
            double mag = magnitude();
            if (mag == 0.0)
                return Vector(0, 0, 0);
            return this * (1.0 / mag);
        }
    }

    static struct Ray
    {
        Vector orig, dir;

        this(Vector orig, Vector dir)
        {
            this.orig = orig;
            this.dir = dir;
        }
    }

    static struct Color
    {
        double r, g, b;

        this(double r, double g, double b)
        {
            this.r = r;
            this.g = g;
            this.b = b;
        }

        Color opBinary(string op : "*")(double s) const
        {
            return Color(r * s, g * s, b * s);
        }

        Color opBinary(string op : "+")(const Color other) const
        {
            return Color(r + other.r, g + other.g, b + other.b);
        }
    }

    static struct Sphere
    {
        Vector center;
        double radius;
        Color color;

        this(Vector center, double radius, Color color)
        {
            this.center = center;
            this.radius = radius;
            this.color = color;
        }

        Vector getNormal(const Vector pt) const
        {
            return (pt - center).normalize();
        }
    }

    static struct Light
    {
        Vector position;
        Color color;

        this(Vector position, Color color)
        {
            this.position = position;
            this.color = color;
        }
    }

    enum WHITE = Color(1.0, 1.0, 1.0);
    enum RED = Color(1.0, 0.0, 0.0);
    enum GREEN = Color(0.0, 1.0, 0.0);
    enum BLUE = Color(0.0, 0.0, 1.0);

    enum LIGHT1 = Light(Vector(0.7, -1.0, 1.7), WHITE);
    enum LUT = ".-+*XM";

    Sphere[] SCENE = [
        Sphere(Vector(-1.0, 0.0, 3.0), 0.3, RED),
        Sphere(Vector(0.0, 0.0, 3.0), 0.8, GREEN),
        Sphere(Vector(1.0, 0.0, 3.0), 0.4, BLUE)
    ];

protected:
    int w, h;
    uint resultVal;

    override string className() const
    {
        return "TextRaytracer";
    }

private:
    int shadePixel(const Ray ray, const Sphere obj, double tval)
    {
        Vector pi = ray.orig + (ray.dir * tval);
        Color color = diffuseShading(pi, obj, LIGHT1);
        double col = (color.r + color.g + color.b) / 3.0;
        int idx = cast(int)(col * 6.0);
        if (idx < 0)
            idx = 0;
        if (idx >= 6)
            idx = 5;
        return idx;
    }

    double intersectSphere(const Ray ray, const Vector center, double radius)
    {
        Vector l = center - ray.orig;
        double tca = l.dot(ray.dir);
        if (tca < 0.0)
            return -1.0;

        double d2 = l.dot(l) - tca * tca;
        double r2 = radius * radius;
        if (d2 > r2)
            return -1.0;

        double thc = sqrt(r2 - d2);
        double t0 = tca - thc;
        if (t0 > 10000.0)
            return -1.0;

        return t0;
    }

    double clamp(double x, double a, double b)
    {
        if (x < a)
            return a;
        if (x > b)
            return b;
        return x;
    }

    Color diffuseShading(const Vector pi, const Sphere obj, const Light light)
    {
        Vector n = obj.getNormal(pi);
        Vector lightDir = (light.position - pi).normalize();
        double lam1 = lightDir.dot(n);
        double lam2 = clamp(lam1, 0.0, 1.0);
        return (light.color * (lam2 * 0.5)) + (obj.color * 0.3);
    }

public:
    this()
    {
        w = configVal("w");
        h = configVal("h");
        resultVal = 0;
    }

    override void run(int iterationId)
    {
        for (int j = 0; j < h; j++)
        {
            for (int i = 0; i < w; i++)
            {
                double fw = w;
                double fi = i;
                double fj = j;
                double fh = h;

                Ray ray = Ray(Vector(0.0, 0.0, 0.0), Vector((fi - fw / 2.0) / fw,
                        (fj - fh / 2.0) / fh, 1.0).normalize());

                double tval = -1.0;
                Sphere* hitObj = null;

                foreach (ref obj; SCENE)
                {
                    double intersect = intersectSphere(ray, obj.center, obj.radius);
                    if (intersect >= 0.0)
                    {
                        tval = intersect;
                        hitObj = &obj;
                        break;
                    }
                }

                char pixel = ' ';
                if (hitObj !is null && tval >= 0.0)
                {
                    int shade = shadePixel(ray, *hitObj, tval);
                    if (shade >= 0 && shade < LUT.length)
                    {
                        pixel = LUT[shade];
                    }
                }
                resultVal += cast(ubyte) pixel;
            }
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
