package benchmarks;

public abstract class SortBenchmark extends Benchmark {
    protected static final int ARR_SIZE = 100_000;
    
    protected int[] data;
    protected int n;
    private long result;
    
    public SortBenchmark() {
        n = getIterations();
    }
    
    @Override
    public void prepare() {
        data = new int[ARR_SIZE];
        for (int i = 0; i < ARR_SIZE; i++) {
            data[i] = Helper.nextInt(1_000_000);
        }
    }
    
    abstract int[] test();
    
    private String checkNElements(int[] arr, int checkN) {
        int step = arr.length / checkN;
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        
        for (int index = 0; index < arr.length; index += step) {
            sb.append(index).append(':').append(arr[index]).append(',');
        }
        sb.append(']').append('\n');
        
        return sb.toString();
    }
    
    @Override
    public void run() {
        String verify = checkNElements(data, 10);
        
        for (int i = 0; i < n - 1; i++) {
            int[] t = test();
            result = (result + t[t.length / 2]) & 0xFFFFFFFFL;
        }
        
        int[] arr = test();
        verify += checkNElements(data, 10);
        verify += checkNElements(arr, 10);
        
        result = (result + Helper.checksum(verify)) & 0xFFFFFFFFL;
    }
    
    @Override
    public long getResult() {
        return result;
    }
}