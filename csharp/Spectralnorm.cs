public class Spectralnorm : Benchmark
{
    private int _n;
    private uint _result;
    
    public override long Result => _result;
    
    public Spectralnorm()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Spectralnorm);
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
    
    private double EvalA(int i, int j)
    {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
    }
    
    private double[] EvalATimesU(double[] u)
    {
        double[] result = new double[u.Length];
        
        for (int i = 0; i < u.Length; i++)
        {
            double sum = 0.0;
            for (int j = 0; j < u.Length; j++)
            {
                sum += EvalA(i, j) * u[j];
            }
            result[i] = sum;
        }
        
        return result;
    }
    
    private double[] EvalAtTimesU(double[] u)
    {
        double[] result = new double[u.Length];
        
        for (int i = 0; i < u.Length; i++)
        {
            double sum = 0.0;
            for (int j = 0; j < u.Length; j++)
            {
                sum += EvalA(j, i) * u[j];
            }
            result[i] = sum;
        }
        
        return result;
    }
    
    private double[] EvalAtATimesU(double[] u)
    {
        return EvalAtTimesU(EvalATimesU(u));
    }
    
    public override void Run()
    {
        double[] u = new double[_n];
        double[] v = new double[_n];
        
        // Инициализация
        for (int i = 0; i < _n; i++)
        {
            u[i] = 1.0;
            v[i] = 1.0;
        }
        
        // 10 итераций
        for (int iter = 0; iter < 10; iter++)
        {
            v = EvalAtATimesU(u);
            u = EvalAtATimesU(v);
        }
        
        // Вычисление vBv и vv
        double vBv = 0.0;
        double vv = 0.0;
        
        for (int i = 0; i < _n; i++)
        {
            vBv += u[i] * v[i];
            vv += v[i] * v[i];
        }
        
        double value = Math.Sqrt(vBv / vv);
        _result = Helper.Checksum(value);
    }
}