package benchmarks;

import java.util.Arrays;

public class SortSelf extends SortBenchmark {

    @Override
    public String name() {
        return "Sort::Self";
    }

    @Override
    int[] test() {
        int[] arr = data.clone();
        Arrays.sort(arr);
        return arr;
    }
}