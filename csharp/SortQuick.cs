public class SortQuick : SortBenchmark
{
    protected override int[] Test()
    {
        int[] arr = new int[_data.Length];
        Array.Copy(_data, arr, _data.Length);
        QuickSort(arr, 0, arr.Length - 1);
        return arr;
    }

    private void QuickSort(int[] arr, int low, int high)
    {
        if (low >= high) return;

        int pivot = arr[(low + high) / 2];
        int i = low, j = high;

        while (i <= j)
        {
            while (arr[i] < pivot) i++;
            while (arr[j] > pivot) j--;

            if (i <= j)
            {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                i++;
                j--;
            }
        }

        QuickSort(arr, low, j);
        QuickSort(arr, i, high);
    }
}