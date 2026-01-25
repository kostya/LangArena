package benchmarks;

public abstract class BufferHashBenchmark extends Benchmark {
    protected byte[] data;
    private long result;
    private int n;
    
    public BufferHashBenchmark() {
        n = getIterations();
    }
    
    @Override
    public void prepare() {
        // Генерируем случайные данные для хэширования
        data = new byte[1_000_000];
        for (int i = 0; i < data.length; i++) {
            data[i] = (byte) Helper.nextInt(256);
        }
    }
    
    abstract long test();
    
    @Override
    public void run() {
        for (int i = 0; i < n; i++) {
            result = (result + test()) & 0xFFFFFFFFL;
        }
    }
    
    @Override
    public long getResult() {
        return result;
    }
}