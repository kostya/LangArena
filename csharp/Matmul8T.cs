using System.Threading.Tasks;

public class Matmul8T : Benchmark
{
    private int _n;
    private uint _result;

    public Matmul8T()
    {
        _result = 0;
        _n = (int)ConfigVal("n");
    }

    public override void Run(long IterationId)
    {
        double[][] a = MatGen(_n);
        double[][] b = MatGen(_n);
        double[][] c = MatMulParallel(a, b);

        double value = c[_n >> 1][_n >> 1];
        _result += Helper.Checksum(value);
    }

    public override uint Checksum => _result;

    private double[][] MatMulParallel(double[][] a, double[][] b)
    {
        int size = a.Length;

        double[][] bT = new double[size][];
        for (int i = 0; i < size; i++)
        {
            bT[i] = new double[size];
            for (int j = 0; j < size; j++)
            {
                bT[i][j] = b[j][i];
            }
        }

        double[][] c = new double[size][];

        for (int i = 0; i < size; i++)
        {
            c[i] = new double[size];
        }

        Parallel.For(0, size, new ParallelOptions { MaxDegreeOfParallelism = 8 }, i =>
        {
            double[] ai = a[i];
            double[] ci = c[i];

            for (int j = 0; j < size; j++)
            {
                double sum = 0.0;
                double[] bTj = bT[j];

                for (int k = 0; k < size; k++)
                {
                    sum += ai[k] * bTj[k];
                }

                ci[j] = sum;
            }
        });

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
}