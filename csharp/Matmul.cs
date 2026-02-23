using System.Threading.Tasks;

public abstract class MatmulBase : Benchmark
{
    protected int _n;
    protected uint _result;
    protected double[][] _a;
    protected double[][] _b;

    protected MatmulBase(string typeName)
    {
        TypeName = typeName;
        _result = 0;
    }

    public override uint Checksum => _result;
    public override string TypeName { get; }

    public override void Prepare()
    {
        _n = (int)ConfigVal("n");
        _a = MatGen(_n);
        _b = MatGen(_n);
        _result = 0;
    }

    protected double[][] MatGen(int n)
    {
        double tmp = 1.0 / n / n;
        double[][] a = new double[n][];

        for (int i = 0; i < n; i++)
        {
            a[i] = new double[n];
            for (int j = 0; j < n; j++)
                a[i][j] = tmp * (i - j) * (i + j);
        }

        return a;
    }
}

public class Matmul1T : MatmulBase
{
    public Matmul1T() : base("Matmul::Single") { }

    private double[][] MatMul(double[][] a, double[][] b)
    {
        int n = a.Length;

        double[][] b2 = new double[n][];
        for (int i = 0; i < n; i++)
        {
            b2[i] = new double[n];
            for (int j = 0; j < n; j++)
                b2[i][j] = b[j][i];
        }

        double[][] c = new double[n][];
        for (int i = 0; i < n; i++)
        {
            c[i] = new double[n];
            double[] ai = a[i];
            double[] ci = c[i];

            for (int j = 0; j < n; j++)
            {
                double[] b2j = b2[j];
                double s = 0.0;

                for (int k = 0; k < n; k++)
                    s += ai[k] * b2j[k];

                ci[j] = s;
            }
        }

        return c;
    }

    public override void Run(long iterationId)
    {
        double[][] c = MatMul(_a, _b);
        double value = c[_n >> 1][_n >> 1];
        _result += Helper.Checksum(value);
    }
}

public abstract class MatmulParallel : MatmulBase
{
    protected int _maxDegreeOfParallelism;

    protected MatmulParallel(string typeName, int maxDegreeOfParallelism) : base(typeName)
    {
        _maxDegreeOfParallelism = maxDegreeOfParallelism;
    }

    protected double[][] MatMulParallel(double[][] a, double[][] b)
    {
        int n = a.Length;

        double[][] bT = new double[n][];
        for (int i = 0; i < n; i++)
        {
            bT[i] = new double[n];
            for (int j = 0; j < n; j++)
                bT[i][j] = b[j][i];
        }

        double[][] c = new double[n][];
        for (int i = 0; i < n; i++)
            c[i] = new double[n];

        Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = _maxDegreeOfParallelism }, i =>
        {
            double[] ai = a[i];
            double[] ci = c[i];

            for (int j = 0; j < n; j++)
            {
                double sum = 0.0;
                double[] bTj = bT[j];

                for (int k = 0; k < n; k++)
                    sum += ai[k] * bTj[k];

                ci[j] = sum;
            }
        });

        return c;
    }

    public override void Run(long iterationId)
    {
        double[][] c = MatMulParallel(_a, _b);
        double value = c[_n >> 1][_n >> 1];
        _result += Helper.Checksum(value);
    }
}

public class Matmul4T : MatmulParallel
{
    public Matmul4T() : base("Matmul::T4", 4) { }
}

public class Matmul8T : MatmulParallel
{
    public Matmul8T() : base("Matmul::T8", 8) { }
}

public class Matmul16T : MatmulParallel
{
    public Matmul16T() : base("Matmul::T16", 16) { }
}