using System.Text;

public class TextRaytracer : Benchmark
{
    private record struct Vector(double X, double Y, double Z)
    {
        public Vector Scale(double s) => new(X * s, Y * s, Z * s);
        public Vector Add(Vector other) => new(X + other.X, Y + other.Y, Z + other.Z);
        public Vector Subtract(Vector other) => new(X - other.X, Y - other.Y, Z - other.Z);
        public double Dot(Vector other) => X * other.X + Y * other.Y + Z * other.Z;
        public double Magnitude => Math.Sqrt(Dot(this));
        public Vector Normalize() => Scale(1.0 / Magnitude);
    }

    private record struct Ray(Vector Orig, Vector Dir);
    private record struct Color(double R, double G, double B)
    {
        public Color Scale(double s) => new(R * s, G * s, B * s);
        public Color Add(Color other) => new(R + other.R, G + other.G, B + other.B);
    }

    private record Sphere(Vector Center, double Radius, Color SphereColor)
    {
        public Vector GetNormal(Vector pt) => pt.Subtract(Center).Normalize();
    }

    private record Light(Vector Position, Color LightColor);

    private static readonly Color WHITE = new(1.0, 1.0, 1.0);
    private static readonly Color RED = new(1.0, 0.0, 0.0);
    private static readonly Color GREEN = new(0.0, 1.0, 0.0);
    private static readonly Color BLUE = new(0.0, 0.0, 1.0);

    private static readonly Light LIGHT1 = new(new Vector(0.7, -1.0, 1.7), WHITE);
    private static readonly char[] LUT = ['.', '-', '+', '*', 'X', 'M'];

    private static readonly Sphere[] SCENE =
    [
        new Sphere(new Vector(-1.0, 0.0, 3.0), 0.3, RED),
        new Sphere(new Vector(0.0, 0.0, 3.0), 0.8, GREEN),
        new Sphere(new Vector(1.0, 0.0, 3.0), 0.4, BLUE),
    ];

    private int _w;
    private int _h;
    private uint _result;

    public TextRaytracer()
    {
        _result = 0;
        _w = (int)ConfigVal("w");
        _h = (int)ConfigVal("h");
    }

    private int ShadePixel(Ray ray, Sphere obj, double tval)
    {
        Vector pi = ray.Orig.Add(ray.Dir.Scale(tval));
        Color color = DiffuseShading(pi, obj, LIGHT1);
        double col = (color.R + color.G + color.B) / 3.0;

        int idx = (int)(col * 6.0);
        if (idx < 0) idx = 0;
        if (idx >= 6) idx = 5;
        return idx;
    }

    private double? IntersectSphere(Ray ray, Vector center, double radius)
    {
        Vector l = center.Subtract(ray.Orig);
        double tca = l.Dot(ray.Dir);

        if (tca < 0.0) return null;

        double d2 = l.Dot(l) - tca * tca;
        double r2 = radius * radius;

        if (d2 > r2) return null;

        double thc = Math.Sqrt(r2 - d2);
        double t0 = tca - thc;

        if (t0 > 10000) return null;

        return t0;
    }

    private double Clamp(double x, double a, double b)
    {
        if (x < a) return a;
        if (x > b) return b;
        return x;
    }

    private Color DiffuseShading(Vector pi, Sphere obj, Light light)
    {
        Vector n = obj.GetNormal(pi);
        Vector lightDir = light.Position.Subtract(pi).Normalize();
        double lam1 = lightDir.Dot(n);
        double lam2 = Clamp(lam1, 0.0, 1.0);

        return light.LightColor.Scale(lam2 * 0.5).Add(obj.SphereColor.Scale(0.3));
    }

    public override void Run(long IterationId)
    {
        int h = _h;

        for (int j = 0; j < h; j++)
        {
            for (int i = 0; i < _w; i++)
            {
                double fw = _w;
                double fi = i;
                double fj = j;
                double fh = h;

                Ray ray = new(
                    new Vector(0.0, 0.0, 0.0),
                    new Vector(
                        (fi - fw / 2.0) / fw,
                        (fj - fh / 2.0) / fh,
                        1.0
                    ).Normalize()
                );

                Sphere? hitObj = null;
                double? tval = null;

                foreach (var obj in SCENE)
                {
                    double? ret = IntersectSphere(ray, obj.Center, obj.Radius);
                    if (ret.HasValue)
                    {
                        hitObj = obj;
                        tval = ret.Value;
                        break;  
                    }
                }

                char pixel = ' ';
                if (hitObj != null && tval.HasValue)
                {
                    int shadeIdx = ShadePixel(ray, hitObj, tval.Value);
                    pixel = LUT[shadeIdx];
                }
                _result += (byte)pixel;
            }
        }
    }

    public override uint Checksum => _result;
}