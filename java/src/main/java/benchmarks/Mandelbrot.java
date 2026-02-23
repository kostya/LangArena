package benchmarks;

import java.io.ByteArrayOutputStream;

public class Mandelbrot extends Benchmark {
    private static final int ITER = 50;
    private static final double LIMIT = 2.0;

    private int w, h;
    private ByteArrayOutputStream result;

    public Mandelbrot() {
        w = (int) configVal("w");
        h = (int) configVal("h");
        result = new ByteArrayOutputStream();
    }

    @Override
    public String name() {
        return "CLBG::Mandelbrot";
    }

    @Override
    public void run(int iterationId) {
        try {
            result.write(("P4\n" + w + " " + h + "\n").getBytes());

            int bitNum = 0;
            byte byteAcc = 0;

            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    double zr = 0.0, zi = 0.0;
                    double tr = 0.0, ti = 0.0;
                    double cr = (2.0 * x / w - 1.5);
                    double ci = (2.0 * y / h - 1.0);

                    int i = 0;
                    while (i < ITER && (tr + ti <= LIMIT * LIMIT)) {
                        zi = 2.0 * zr * zi + ci;
                        zr = tr - ti + cr;
                        tr = zr * zr;
                        ti = zi * zi;
                        i++;
                    }

                    byteAcc <<= 1;
                    if (tr + ti <= LIMIT * LIMIT) {
                        byteAcc |= 0x01;
                    }
                    bitNum++;

                    if (bitNum == 8) {
                        result.write(byteAcc);
                        byteAcc = 0;
                        bitNum = 0;
                    } else if (x == w - 1) {
                        byteAcc <<= (8 - (w % 8));
                        result.write(byteAcc);
                        byteAcc = 0;
                        bitNum = 0;
                    }
                }
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public long checksum() {
        return Helper.checksum(result.toByteArray());
    }
}