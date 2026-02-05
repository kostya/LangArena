public class Spectralnorm : Benchmark
{
    private long _size;
    private double[] _u;
    private double[] _v;
    private uint _result;

    public Spectralnorm()
    {
        _size = ConfigVal("size");
        _u = new double[_size];
        _v = new double[_size];

        Array.Fill(_u, 1.0);
        Array.Fill(_v, 1.0);
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
            for (int j = 0; j < u.Length; j++) sum += EvalA(i, j) * u[j];
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
            for (int j = 0; j < u.Length; j++) sum += EvalA(j, i) * u[j];
            result[i] = sum;
        }

        return result;
    }

    private double[] EvalAtATimesU(double[] u) => EvalAtTimesU(EvalATimesU(u));

    public override void Run(long IterationId)
    {
        _v = EvalAtATimesU(_u);
        _u = EvalAtATimesU(_v);
    }

    public override uint Checksum
    {
        get
        {
            double vBv = 0.0;
            double vv = 0.0;

            for (int i = 0; i < _size; i++)
            {
                vBv += _u[i] * _v[i];
                vv += _v[i] * _v[i];
            }

            return Helper.Checksum(Math.Sqrt(vBv / vv));
        }
    }
}