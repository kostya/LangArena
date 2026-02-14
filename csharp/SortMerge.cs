public class SortMerge : SortBenchmark
{
    protected override int[] Test()
    {
        int[] arr = new int[_data.Length];
        Array.Copy(_data, arr, _data.Length);
        MergeSortInplace(arr);
        return arr;
    }

    private void MergeSortInplace(int[] arr)
    {
        int[] temp = new int[arr.Length];
        MergeSortHelper(arr, temp, 0, arr.Length - 1);
    }

    private void MergeSortHelper(int[] arr, int[] temp, int left, int right)
    {
        if (left >= right) return;

        int mid = (left + right) / 2;
        MergeSortHelper(arr, temp, left, mid);
        MergeSortHelper(arr, temp, mid + 1, right);
        Merge(arr, temp, left, mid, right);
    }

    private void Merge(int[] arr, int[] temp, int left, int mid, int right)
    {
        Array.Copy(arr, left, temp, left, right - left + 1);

        int iIdx = left;
        int jIdx = mid + 1;
        int k = left;

        while (iIdx <= mid && jIdx <= right)
        {
            if (temp[iIdx] <= temp[jIdx]) arr[k] = temp[iIdx++];
            else arr[k] = temp[jIdx++];
            k++;
        }

        while (iIdx <= mid) arr[k++] = temp[iIdx++];
    }
}