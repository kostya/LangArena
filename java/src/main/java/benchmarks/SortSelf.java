package benchmarks;

import java.util.Arrays;

public class SortSelf extends SortBenchmark {
    
    @Override
    int[] test() {
        int[] arr = data.clone();
        Arrays.sort(arr);
        return arr;
    }
}