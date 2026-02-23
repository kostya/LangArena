package benchmarks;

public class SortMerge extends SortBenchmark {

    @Override
    public String name() {
        return "Sort::Merge";
    }

    @Override
    int[] test() {
        int[] arr = data.clone();
        mergeSortInplace(arr);
        return arr;
    }

    private void mergeSortInplace(int[] arr) {
        int[] temp = new int[arr.length];
        mergeSortHelper(arr, temp, 0, arr.length - 1);
    }

    private void mergeSortHelper(int[] arr, int[] temp, int left, int right) {
        if (left >= right) return;

        int mid = (left + right) / 2;
        mergeSortHelper(arr, temp, left, mid);
        mergeSortHelper(arr, temp, mid + 1, right);
        merge(arr, temp, left, mid, right);
    }

    private void merge(int[] arr, int[] temp, int left, int mid, int right) {
        System.arraycopy(arr, left, temp, left, right - left + 1);

        int i = left;
        int j = mid + 1;
        int k = left;

        while (i <= mid && j <= right) {
            if (temp[i] <= temp[j]) {
                arr[k] = temp[i];
                i++;
            } else {
                arr[k] = temp[j];
                j++;
            }
            k++;
        }

        while (i <= mid) {
            arr[k] = temp[i];
            i++;
            k++;
        }
    }
}