module benchmarks.spectralnorm;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import benchmark;
import helper;

class Spectralnorm : Benchmark {
private:
    int sizeVal;
    double[] u;
    double[] v;

    double evalA(ulong i, ulong j) {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
    }

    double[] evalATimesU(double[] u) {
        double[] v = new double[u.length];

        for (int i = 0; i < u.length; i++) {  
            double sum = 0.0;
            foreach (j, ref val; u) sum += evalA(i, j) * val;
            v[i] = sum;
        }

        return v;
    }

    double[] evalAtTimesU(double[] u) {
        double[] v = new double[u.length];

        for (int i = 0; i < u.length; i++) {  
            double sum = 0.0;
            foreach (j, ref val; u) sum += evalA(j, i) * val;
            v[i] = sum;
        }

        return v;
    }

    double[] evalAtATimesU(double[] u) {
        return evalAtTimesU(evalATimesU(u));
    }

protected:
    override string className() const { return "Spectralnorm"; }

public:
    this() {
        sizeVal = configVal("size");
        u = new double[sizeVal];
        v = new double[sizeVal];

        u[] = 1.0;
        v[] = 1.0;
    }

    override void run(int iterationId) {
        v = evalAtATimesU(u);
        u = evalAtATimesU(v);
    }

    override uint checksum() {
        double vBv = 0.0, vv = 0.0;
        for (int i = 0; i < sizeVal; i++) {  
            vBv += u[i] * v[i];
            vv += v[i] * v[i];
        }
        return Helper.checksumF64(sqrt(vBv / vv));
    }
}