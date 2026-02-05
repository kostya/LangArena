public class Matmul1T : Benchmark
{
    private int _n;
    private uint _result;

    public Matmul1T()
    {
        _result = 0;
        _n = (int)ConfigVal("n");
    }

    public override void Run(long IterationId)
    {
        double[][] a = MatGen(_n);
        double[][] b = MatGen(_n);
        double[][] c = MatMul(a, b);

        double value = c[_n >> 1][_n >> 1];
        _result += Helper.Checksum(value);
    }

    public override uint Checksum => _result;

    private double[][] MatMul(double[][] a, double[][] b)
    {
        int m = a.Length;
        int n = a[0].Length;
        int p = b[0].Length;

        double[][] b2 = new double[n][];
        for (int i = 0; i < n; i++)
        {
            b2[i] = new double[p];
            for (int j = 0; j < p; j++) b2[i][j] = b[j][i];
        }

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

                for (int k = 0; k < n; k++) s += ai[k] * b2j[k];

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
            for (int j = 0; j < n; j++) a[i][j] = tmp * (i - j) * (i + j);
        }

        return a;
    }
}