module benchmarks.matmul4t;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.parallelism;
import std.datetime;
import std.range : iota;
import benchmark;
import helper;

class Matmul4T : Benchmark
{
protected:
    int n;
    uint resultVal;

    int getNumThreads() const
    {
        return 4;
    }

    double[][] matgen(int size)
    {
        double tmp = 1.0 / size / size;
        double[][] a = new double[][](size);

        foreach (i; 0 .. size)
        {
            a[i] = new double[size];
            foreach (j; 0 .. size)
            {
                a[i][j] = tmp * (i - j) * (i + j);
            }
        }
        return a;
    }

    double[][] matmulParallel(double[][] a, double[][] b)
    {
        int numThreads = getNumThreads();
        int size = cast(int) a.length;

        double[][] bT = new double[][](size);
        foreach (j; 0 .. size)
        {
            bT[j] = new double[size];
            foreach (i; 0 .. size)
            {
                bT[j][i] = b[i][j];
            }
        }

        double[][] c = new double[][](size);

        auto tp = new TaskPool(numThreads);
        scope (exit)
            tp.finish();

        foreach (i; tp.parallel(iota(size)))
        {
            c[i] = new double[size];
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
        }

        return c;
    }

protected:
    override string className() const
    {
        return "Matmul4T";
    }

public:
    this()
    {
        n = configVal("n");
        resultVal = 0;
    }

    override void run(int iterationId)
    {
        auto a = matgen(n);
        auto b = matgen(n);
        auto c = matmulParallel(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class Matmul8T : Matmul4T
{
protected:
    override string className() const
    {
        return "Matmul8T";
    }

    override int getNumThreads() const
    {
        return 8;
    }
}

class Matmul16T : Matmul4T
{
protected:
    override string className() const
    {
        return "Matmul16T";
    }

    override int getNumThreads() const
    {
        return 16;
    }
}
