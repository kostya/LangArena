public class Noise : Benchmark
{
    private const int SIZE = 64;
    private int _n;
    private ulong _result;
    
    public override long Result => (long)_result;
    
    public Noise()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Noise);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
                return;
            }
        }
        _n = 1;
    }
    
    private record struct Vec2(double X, double Y);
    
    private static double Lerp(double a, double b, double v)
    {
        return a * (1.0 - v) + b * v;
    }
    
    private static double Smooth(double v)
    {
        return v * v * (3.0 - 2.0 * v);
    }
    
    private static Vec2 RandomGradient()
    {
        double v = Helper.NextFloat() * Math.PI * 2.0;
        return new Vec2(Math.Cos(v), Math.Sin(v));
    }
    
    private static double Gradient(Vec2 orig, Vec2 grad, Vec2 p)
    {
        Vec2 sp = new(p.X - orig.X, p.Y - orig.Y);
        return grad.X * sp.X + grad.Y * sp.Y;
    }
    
    private class Noise2DContext
    {
        private readonly Vec2[] _rgradients;
        private readonly int[] _permutations;
        
        public Noise2DContext()
        {
            _rgradients = new Vec2[SIZE];
            _permutations = new int[SIZE];
            
            for (int i = 0; i < SIZE; i++)
            {
                _rgradients[i] = RandomGradient();
                _permutations[i] = i;
            }
            
            // Shuffle permutations
            for (int i = 0; i < SIZE; i++)
            {
                int a = Helper.NextInt(SIZE);
                int b = Helper.NextInt(SIZE);
                (_permutations[a], _permutations[b]) = (_permutations[b], _permutations[a]);
            }
        }
        
        private Vec2 GetGradient(int x, int y)
        {
            int idx = _permutations[x & (SIZE - 1)] + _permutations[y & (SIZE - 1)];
            return _rgradients[idx & (SIZE - 1)];
        }
        
        public (Vec2[], Vec2[]) GetGradients(double x, double y)
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
    }
    
    private static readonly char[] SYM = [' ', '░', '▒', '▓', '█', '█'];
    
    private ulong NoiseAlgo()
    {
        double[][] pixels = new double[SIZE][];
        for (int i = 0; i < SIZE; i++)
            pixels[i] = new double[SIZE];
        
        var n2d = new Noise2DContext();
        
        for (int i = 0; i < 100; i++)
        {
            for (int y = 0; y < SIZE; y++)
            {
                for (int x = 0; x < SIZE; x++)
                {
                    double v = n2d.Get(x * 0.1, (y + (i * 128)) * 0.1) * 0.5 + 0.5;
                    pixels[y][x] = v;
                }
            }
        }
        
        ulong res = 0;
        
        for (int y = 0; y < SIZE; y++)
        {
            for (int x = 0; x < SIZE; x++)
            {
                double v = pixels[y][x];
                int idx = (int)(v / 0.2);
                if (idx >= SYM.Length) idx = SYM.Length - 1;
                res += (ulong)SYM[idx];
            }
        }
        
        return res;
    }
    
    public override void Run()
    {
        for (int i = 0; i < _n; i++)
        {
            ulong v = NoiseAlgo();
            unchecked
            {
                _result += v;
            }
        }
    }
}