package benchmarks;

import java.util.concurrent.ForkJoinPool;
import java.util.stream.IntStream;

public class Matmul16T extends Matmul4T {

    public Matmul16T() {
        n = (int) configVal("n");
        resultVal = 0L;
        POOL = new ForkJoinPool(16);
    }

    @Override
    public String name() {
        return "Matmul::T16";
    }
}