package benchmarks;

public class SortQuick extends SortBenchmark {

    @Override
    public String name() {
        return "Sort::Quick";
    }

    @Override
    int[] test() {
        int[] arr = data.clone();
        quickSort(arr, 0, arr.length - 1);
        return arr;
    }

    private void quickSort(int[] arr, int low, int high) {
        if (low >= high) return;

        int pivot = arr[(low + high) / 2];
        int i = low, j = high;

        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (arr[j] > pivot) j--;
            if (i <= j) {
                int temp = arr[i];
                arr[i] = arr[j];
                arr[j] = temp;
                i++;
                j--;
            }
        }

        quickSort(arr, low, j);
        quickSort(arr, i, high);
    }
}