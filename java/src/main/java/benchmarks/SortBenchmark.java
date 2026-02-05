package benchmarks;

public abstract class SortBenchmark extends Benchmark {
    protected int[] data;
    protected long sizeVal;
    private long resultVal;

    public SortBenchmark() {
        resultVal = 0L;
        sizeVal = 0L;
    }

    @Override
    public void prepare() {
        if (sizeVal == 0) {
            sizeVal = configVal("size");
            data = new int[(int) sizeVal];
            for (int i = 0; i < data.length; i++) {
                data[i] = Helper.nextInt(1_000_000);
            }
        }
    }

    abstract int[] test();

    @Override
    public void run(int iterationId) {

        resultVal += data[Helper.nextInt(data.length)];
        int[] t = test();
        resultVal += t[Helper.nextInt(data.length)];
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}