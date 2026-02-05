package benchmarks;

import java.util.concurrent.ForkJoinPool;
import java.util.stream.IntStream;

public class Matmul8T extends Matmul4T {

    public Matmul8T() {
        n = (int) configVal("n");
        resultVal = 0L;
        POOL = new ForkJoinPool(8);
    }

    @Override
    public String name() {
        return "Matmul8T";
    }
}