package benchmarks;

import java.util.Arrays;

public class Spectralnorm extends Benchmark {
    private int sizeVal;
    private double[] u;
    private double[] v;

    public Spectralnorm() {
        sizeVal = (int) configVal("size");
        u = new double[sizeVal];
        v = new double[sizeVal];
        Arrays.fill(u, 1.0);
        Arrays.fill(v, 1.0);
    }

    @Override
    public String name() {
        return "Spectralnorm";
    }

    private double evalA(int i, int j) {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0);
    }

    private double[] evalATimesU(double[] u) {
        double[] result = new double[u.length];
        for (int i = 0; i < u.length; i++) {
            double v = 0.0;
            for (int j = 0; j < u.length; j++) {
                v += evalA(i, j) * u[j];
            }
            result[i] = v;
        }
        return result;
    }

    private double[] evalAtTimesU(double[] u) {
        double[] result = new double[u.length];
        for (int i = 0; i < u.length; i++) {
            double v = 0.0;
            for (int j = 0; j < u.length; j++) {
                v += evalA(j, i) * u[j];
            }
            result[i] = v;
        }
        return result;
    }

    private double[] evalAtATimesU(double[] u) {
        return evalAtTimesU(evalATimesU(u));
    }

    @Override
    public void run(int iterationId) {
        v = evalAtATimesU(u);
        u = evalAtATimesU(v);
    }

    @Override
    public long checksum() {
        double vBv = 0.0;
        double vv = 0.0;
        for (int i = 0; i < sizeVal; i++) {
            vBv += u[i] * v[i];
            vv += v[i] * v[i];
        }
        return Helper.checksumF64(Math.sqrt(vBv / vv));
    }
}