public class Noise : Benchmark
{
    private struct Vec2
    {
        public double X;
        public double Y;

        public Vec2(double x, double y) { X = x; Y = y; }
    }

    private class Noise2DContext
    {
        private readonly Vec2[] _rgradients;
        private readonly int[] _permutations;
        private readonly int _sizeMask;

        public Noise2DContext(int size)
        {
            _sizeMask = size - 1;
            _rgradients = new Vec2[size];
            _permutations = new int[size];

            for (int i = 0; i < size; i++)
            {
                double v = Helper.NextFloat() * Math.PI * 2.0;
                _rgradients[i] = new Vec2(Math.Cos(v), Math.Sin(v));
                _permutations[i] = i;
            }

            for (int i = 0; i < size; i++)
            {
                int a = Helper.NextInt(size);
                int b = Helper.NextInt(size);
                (_permutations[a], _permutations[b]) = (_permutations[b], _permutations[a]);
            }
        }

        private static double Gradient(in Vec2 orig, in Vec2 grad, in Vec2 p)
        {
            double spX = p.X - orig.X;
            double spY = p.Y - orig.Y;
            return grad.X * spX + grad.Y * spY;
        }

        private static double Lerp(double a, double b, double v) => a * (1.0 - v) + b * v;
        private static double Smooth(double v) => v * v * (3.0 - 2.0 * v);

        private Vec2 GetGradient(int x, int y)
        {
            int idx = _permutations[x & _sizeMask] + _permutations[y & _sizeMask];
            return _rgradients[idx & _sizeMask];
        }

        public double Get(double x, double y)
        {
            double x0f = Math.Floor(x);
            double y0f = Math.Floor(y);
            int x0 = (int)x0f;
            int y0 = (int)y0f;

            Vec2 g00 = GetGradient(x0, y0);
            Vec2 g10 = GetGradient(x0 + 1, y0);
            Vec2 g01 = GetGradient(x0, y0 + 1);
            Vec2 g11 = GetGradient(x0 + 1, y0 + 1);

            Vec2 p = new(x, y);

            double v0 = Gradient(new(x0f, y0f), g00, p);
            double v1 = Gradient(new(x0f + 1.0, y0f), g10, p);
            double v2 = Gradient(new(x0f, y0f + 1.0), g01, p);
            double v3 = Gradient(new(x0f + 1.0, y0f + 1.0), g11, p);

            double fx = Smooth(x - x0f);
            double vx0 = Lerp(v0, v1, fx);
            double vx1 = Lerp(v2, v3, fx);

            double fy = Smooth(y - y0f);
            return Lerp(vx0, vx1, fy);
        }
    }

    private static readonly char[] SYM = [' ', '░', '▒', '▓', '█', '█'];
    private const int SYM_LENGTH = 6;

    private long _size;
    private uint _result;
    private Noise2DContext _n2d;

    public Noise()
    {
        _result = 0;
        _size = ConfigVal("size");
        _n2d = new Noise2DContext((int)_size);
    }

    public override void Run(long IterationId)
    {
        double yAdd = IterationId * 128 * 0.1;
        double step = 0.1;

        for (long y = 0; y < _size; y++)
        {
            double yf = y * step + yAdd;
            for (long x = 0; x < _size; x++)
            {
                double xf = x * step;
                double v = _n2d.Get(xf, yf) * 0.5 + 0.5;

                int idx = (int)(v * 5.0);
                if (idx >= SYM_LENGTH) idx = SYM_LENGTH - 1;
                _result += (uint)SYM[idx];
            }
        }
    }

    public override uint Checksum => _result;
}