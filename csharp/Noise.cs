public class Noise : Benchmark
{
    private record struct Vec2(double X, double Y);

    private class Noise2DContext
    {
        private readonly Vec2[] _rgradients;
        private readonly int[] _permutations;
        private readonly int _size;

        public Noise2DContext(int size)
        {
            _size = size;
            _rgradients = new Vec2[size];
            _permutations = new int[size];

            for (int i = 0; i < size; i++)
            {
                _rgradients[i] = RandomGradient();
                _permutations[i] = i;
            }

            for (int i = 0; i < size; i++)
            {
                int a = Helper.NextInt(size);
                int b = Helper.NextInt(size);
                (_permutations[a], _permutations[b]) = (_permutations[b], _permutations[a]);
            }
        }

        private static Vec2 RandomGradient()
        {
            double v = Helper.NextFloat() * Math.PI * 2.0;
            return new Vec2(Math.Cos(v), Math.Sin(v));
        }

        public double Get(double x, double y)
        {
            Vec2 p = new(x, y);
            var (gradients, origins) = GetGradients(x, y);

            double v0 = Gradient(origins[0], gradients[0], p);
            double v1 = Gradient(origins[1], gradients[1], p);
            double v2 = Gradient(origins[2], gradients[2], p);
            double v3 = Gradient(origins[3], gradients[3], p);

            double fx = Smooth(x - origins[0].X);
            double vx0 = Lerp(v0, v1, fx);
            double vx1 = Lerp(v2, v3, fx);

            double fy = Smooth(y - origins[0].Y);
            return Lerp(vx0, vx1, fy);
        }

        private (Vec2[], Vec2[]) GetGradients(double x, double y)
        {
            double x0f = Math.Floor(x);
            double y0f = Math.Floor(y);
            int x0 = (int)x0f;
            int y0 = (int)y0f;
            int x1 = x0 + 1;
            int y1 = y0 + 1;

            var gradients = new Vec2[]
            {
                GetGradient(x0, y0),
                GetGradient(x1, y0),
                GetGradient(x0, y1),
                GetGradient(x1, y1)
            };

            var origins = new Vec2[]
            {
                new(x0f + 0.0, y0f + 0.0),
                new(x0f + 1.0, y0f + 0.0),
                new(x0f + 0.0, y0f + 1.0),
                new(x0f + 1.0, y0f + 1.0)
            };

            return (gradients, origins);
        }

        private Vec2 GetGradient(int x, int y)
        {
            int idx = _permutations[x & (_size - 1)] + _permutations[y & (_size - 1)];
            return _rgradients[idx & (_size - 1)];
        }

        private static double Gradient(Vec2 orig, Vec2 grad, Vec2 p)
        {
            Vec2 sp = new(p.X - orig.X, p.Y - orig.Y);
            return grad.X * sp.X + grad.Y * sp.Y;
        }

        private static double Lerp(double a, double b, double v) => a * (1.0 - v) + b * v;
        private static double Smooth(double v) => v * v * (3.0 - 2.0 * v);
    }

    private static readonly char[] SYM = [' ', '░', '▒', '▓', '█', '█'];

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
        for (long y = 0; y < _size; y++)
        {
            for (long x = 0; x < _size; x++)
            {
                double v = _n2d.Get(x * 0.1, (y + (IterationId * 128)) * 0.1) * 0.5 + 0.5;
                int idx = (int)(v / 0.2);
                if (idx >= 6) idx = 5;
                _result += (uint)SYM[idx];
            }
        }
    }

    public override uint Checksum => _result;
}