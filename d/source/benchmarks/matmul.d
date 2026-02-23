module benchmarks.matmul;

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

double[][] matgen(int n)
{
    double tmp = 1.0 / n / n;
    auto a = new double[][](n, n);

    foreach (i; 0 .. n)
    {
        foreach (j; 0 .. n)
        {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

double[][] transpose(double[][] b)
{
    int n = cast(int) b.length;
    auto bT = new double[][](n, n);

    foreach (j; 0 .. n)
    {
        foreach (i; 0 .. n)
        {
            bT[j][i] = b[i][j];
        }
    }
    return bT;
}

double[][] matmulSequential(double[][] a, double[][] b)
{
    int n = cast(int) a.length;
    auto bT = transpose(b);
    auto c = new double[][](n, n);

    foreach (i; 0 .. n)
    {
        double[] ai = a[i];
        double[] ci = c[i];

        foreach (j; 0 .. n)
        {
            double s = 0.0;
            double[] bTj = bT[j];

            foreach (k; 0 .. n)
            {
                s += ai[k] * bTj[k];
            }
            ci[j] = s;
        }
    }
    return c;
}

double[][] matmulParallel(double[][] a, double[][] b, int numThreads)
{
    int n = cast(int) a.length;
    auto bT = transpose(b);
    auto c = new double[][](n, n);

    auto tp = new TaskPool(numThreads);
    scope (exit)
        tp.finish();

    foreach (i; tp.parallel(iota(n)))
    {
        double[] ai = a[i];
        double[] ci = c[i];

        for (int j = 0; j < n; j++)
        {
            double sum = 0.0;
            double[] bTj = bT[j];

            for (int k = 0; k < n; k++)
            {
                sum += ai[k] * bTj[k];
            }
            ci[j] = sum;
        }
    }

    return c;
}

class BaseMatmul : Benchmark
{
protected:
    int n;
    uint resultVal;
    double[][] a;
    double[][] b;

    override void prepare()
    {
        n = configVal("n");
        a = matgen(n);
        b = matgen(n);
    }
}

class Matmul1T : BaseMatmul
{
protected:
    override string className() const
    {
        return "Matmul::Single";
    }

public:
    this()
    {
        prepare();
    }

    override void run(int iterationId)
    {
        auto c = matmulSequential(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class Matmul4T : BaseMatmul
{
protected:
    override string className() const
    {
        return "Matmul::T4";
    }

public:
    this()
    {
        prepare();
    }

    override void run(int iterationId)
    {
        auto c = matmulParallel(a, b, 4);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class Matmul8T : BaseMatmul
{
protected:
    override string className() const
    {
        return "Matmul::T8";
    }

public:
    this()
    {
        prepare();
    }

    override void run(int iterationId)
    {
        auto c = matmulParallel(a, b, 8);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class Matmul16T : BaseMatmul
{
protected:
    override string className() const
    {
        return "Matmul::T16";
    }

public:
    this()
    {
        prepare();
    }

    override void run(int iterationId)
    {
        auto c = matmulParallel(a, b, 16);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}
