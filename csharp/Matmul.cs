public class Matmul : Benchmark
{
    private int _n;
    private uint _result;
    
    public override long Result => _result;
    
    public Matmul()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Matmul);
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
    
    private double[][] MatMul(double[][] a, double[][] b)
    {
        int m = a.Length;
        int n = a[0].Length;
        int p = b[0].Length;
        
        // transpose
        double[][] b2 = new double[n][];
        for (int i = 0; i < n; i++)
        {
            b2[i] = new double[p];
            for (int j = 0; j < p; j++)
            {
                b2[i][j] = b[j][i];
            }
        }
        
        // multiplication
        double[][] c = new double[m][];
        for (int i = 0; i < m; i++)
        {
            c[i] = new double[p];
            double[] ai = a[i];
            double[] ci = c[i];
            
            for (int j = 0; j < p; j++)
            {
                double[] b2j = b2[j];
                double s = 0.0;
                
                for (int k = 0; k < n; k++)
                {
                    s += ai[k] * b2j[k];
                }
                
                ci[j] = s;
            }
        }
        
        return c;
    }
    
    private double[][] MatGen(int n)
    {
        double tmp = 1.0 / n / n;
        double[][] a = new double[n][];
        
        for (int i = 0; i < n; i++)
        {
            a[i] = new double[n];
            for (int j = 0; j < n; j++)
            {
                a[i][j] = tmp * (i - j) * (i + j);
            }
        }
        
        return a;
    }
    
    public override void Run()
    {
        double[][] a = MatGen(_n);
        double[][] b = MatGen(_n);
        double[][] c = MatMul(a, b);
        
        double value = c[_n >> 1][_n >> 1];
        _result = Helper.Checksum(value);
    }
}