package benchmarks;

public class Matmul extends Benchmark {
    private int n;
    private long result;
    
    public Matmul() {
        n = getIterations();
    }
    
    private double[][] matmul(double[][] a, double[][] b) {
        int m = a.length;
        int n = a[0].length;
        int p = b[0].length;
        
        // transpose
        double[][] b2 = new double[n][p];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < p; j++) {
                b2[j][i] = b[i][j];
            }
        }
        
        // multiplication
        double[][] c = new double[m][p];
        for (int i = 0; i < m; i++) {
            double[] ci = c[i];
            double[] ai = a[i];
            for (int j = 0; j < p; j++) {
                double s = 0.0;
                double[] b2j = b2[j];
                for (int k = 0; k < n; k++) {
                    s += ai[k] * b2j[k];
                }
                ci[j] = s;
            }
        }
        
        return c;
    }
    
    private double[][] matgen(int n) {
        double tmp = 1.0 / n / n;
        double[][] a = new double[n][n];
        
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                a[i][j] = tmp * (i - j) * (i + j);
            }
        }
        
        return a;
    }
    
    @Override
    public void run() {
        double[][] a = matgen(n);
        double[][] b = matgen(n);
        double[][] c = matmul(a, b);
        
        result = Helper.checksumF64(c[n >> 1][n >> 1]);
    }
    
    @Override
    public long getResult() {
        return result;
    }
}