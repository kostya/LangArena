package benchmarks;

import java.util.concurrent.ForkJoinPool;
import java.util.stream.IntStream;

public class Matmul4T extends Benchmark {
    public int n;
    public long resultVal;
    public static ForkJoinPool POOL = new ForkJoinPool(4);

    public Matmul4T() {
        n = (int) configVal("n");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Matmul::T4";
    }

    private double[][] matgen(int n) {
        double tmp = 1.0 / n / n;
        double[][] a = new double[n][n];

        POOL.submit(() -> {
            IntStream.range(0, n).parallel().forEach(i -> {
                for (int j = 0; j < n; j++) {
                    a[i][j] = tmp * (i - j) * (i + j);
                }
            });
        }).join();

        return a;
    }

    private double[][] matmulParallel(double[][] a, double[][] b) {
        int size = a.length;

        double[][] bT = new double[size][size];
        POOL.submit(() -> {
            IntStream.range(0, size).parallel().forEach(i -> {
                for (int j = 0; j < size; j++) {
                    bT[j][i] = b[i][j];
                }
            });
        }).join();

        double[][] c = new double[size][size];
        POOL.submit(() -> {
            IntStream.range(0, size).parallel().forEach(i -> {
                double[] ai = a[i];
                for (int j = 0; j < size; j++) {
                    double sum = 0.0;
                    double[] bTj = bT[j];
                    for (int k = 0; k < size; k++) {
                        sum += ai[k] * bTj[k];
                    }
                    c[i][j] = sum;
                }
            });
        }).join();

        return c;
    }

    @Override
    public void run(int iterationId) {
        double[][] a = matgen(n);
        double[][] b = matgen(n);
        double[][] c = matmulParallel(a, b);

        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}