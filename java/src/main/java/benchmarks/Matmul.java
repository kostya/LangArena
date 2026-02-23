package benchmarks;

import java.util.concurrent.ForkJoinPool;
import java.util.stream.IntStream;

abstract class MatmulBase extends Benchmark {
    protected int n;
    protected long resultVal;
    protected double[][] a;
    protected double[][] b;
    protected ForkJoinPool pool;

    protected MatmulBase(String name, int threads) {
        this.n = (int) configVal("n");
        this.resultVal = 0L;
        this.pool = threads > 1 ? new ForkJoinPool(threads) : null;
    }

    protected double[][] matgen(int n) {
        double tmp = 1.0 / n / n;
        double[][] a = new double[n][n];

        if (pool != null) {
            pool.submit(() -> {
                IntStream.range(0, n).parallel().forEach(i -> {
                    for (int j = 0; j < n; j++) {
                        a[i][j] = tmp * (i - j) * (i + j);
                    }
                });
            }).join();
        } else {
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    a[i][j] = tmp * (i - j) * (i + j);
                }
            }
        }

        return a;
    }

    protected double[][] transpose(double[][] b) {
        int n = b.length;
        double[][] bT = new double[n][n];

        if (pool != null) {
            pool.submit(() -> {
                IntStream.range(0, n).parallel().forEach(i -> {
                    for (int j = 0; j < n; j++) {
                        bT[j][i] = b[i][j];
                    }
                });
            }).join();
        } else {
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    bT[j][i] = b[i][j];
                }
            }
        }

        return bT;
    }

    protected double[][] matmulSequential(double[][] a, double[][] b) {
        int n = a.length;
        double[][] bT = transpose(b);
        double[][] c = new double[n][n];

        for (int i = 0; i < n; i++) {
            double[] ai = a[i];
            double[] ci = c[i];
            for (int j = 0; j < n; j++) {
                double[] bTj = bT[j];
                double sum = 0.0;

                for (int k = 0; k < n; k++) {
                    sum += ai[k] * bTj[k];
                }
                ci[j] = sum;
            }
        }

        return c;
    }

    protected double[][] matmulParallel(double[][] a, double[][] b) {
        int n = a.length;
        double[][] bT = transpose(b);
        double[][] c = new double[n][n];

        pool.submit(() -> {
            IntStream.range(0, n).parallel().forEach(i -> {
                double[] ai = a[i];
                for (int j = 0; j < n; j++) {
                    double sum = 0.0;
                    double[] bTj = bT[j];

                    for (int k = 0; k < n; k++) {
                        sum += ai[k] * bTj[k];
                    }
                    c[i][j] = sum;
                }
            });
        }).join();

        return c;
    }

    @Override
    public void prepare() {
        a = matgen(n);
        b = matgen(n);
        resultVal = 0L;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class Matmul1T extends MatmulBase {
    public Matmul1T() {
        super("Matmul::Single", 1);
    }

    @Override
    public String name() {
        return "Matmul::Single";
    }

    @Override
    public void run(int iterationId) {
        double[][] c = matmulSequential(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }
}

class Matmul4T extends MatmulBase {
    public Matmul4T() {
        super("Matmul::T4", 4);
    }

    @Override
    public String name() {
        return "Matmul::T4";
    }

    @Override
    public void run(int iterationId) {
        double[][] c = matmulParallel(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }
}

class Matmul8T extends MatmulBase {
    public Matmul8T() {
        super("Matmul::T8", 8);
    }

    @Override
    public String name() {
        return "Matmul::T8";
    }

    @Override
    public void run(int iterationId) {
        double[][] c = matmulParallel(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }
}

class Matmul16T extends MatmulBase {
    public Matmul16T() {
        super("Matmul::T16", 16);
    }

    @Override
    public String name() {
        return "Matmul::T16";
    }

    @Override
    public void run(int iterationId) {
        double[][] c = matmulParallel(a, b);
        resultVal += Helper.checksumF64(c[n >> 1][n >> 1]);
    }
}