package benchmarks;

public abstract class BufferHashBenchmark extends Benchmark {
    protected byte[] data;
    private long resultVal;
    private long sizeVal;

    public BufferHashBenchmark() {
        resultVal = 0L;
        sizeVal = 0L;
    }

    @Override
    public void prepare() {
        if (sizeVal == 0) {
            sizeVal = configVal("size");
            data = new byte[(int) sizeVal];
            for (int i = 0; i < data.length; i++) {
                data[i] = (byte) Helper.nextInt(256);
            }
        }
    }

    abstract long test();

    @Override
    public void run(int iterationId) {
        resultVal += test();
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}