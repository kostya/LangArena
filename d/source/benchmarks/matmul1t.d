module benchmarks.matmul1t;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.parallelism;
import std.datetime;
import benchmark;
import helper;

class Matmul1T : Benchmark
{
private:
    int n;
    uint resultVal;

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

    double[][] matmul(double[][] a, double[][] b)
    {
        int m = cast(int) a.length;
        int n = cast(int) a[0].length;
        int p = cast(int) b[0].length;

        double[][] b2 = new double[][](p);
        foreach (j; 0 .. p)
        {
            b2[j] = new double[n];
        }

        foreach (i; 0 .. n)
        {
            foreach (j; 0 .. p)
            {
                b2[j][i] = b[i][j];
            }
        }

        double[][] c = new double[][](m);
        foreach (i; 0 .. m)
        {
            c[i] = new double[p];
        }

        foreach (i; 0 .. m)
        {
            double[] ai = a[i];
            double[] ci = c[i];
            foreach (j; 0 .. p)
            {
                double s = 0.0;
                double[] b2j = b2[j];
                foreach (k; 0 .. n)
                {
                    s += ai[k] * b2j[k];
                }
                ci[j] = s;
            }
        }
        return c;
    }

protected:
    override string className() const
    {
        return "Matmul1T";
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
        auto c = matmul(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}
