public class SortSelf : SortBenchmark
{
    protected override int[] Test()
    {
        int[] arr = new int[_data.Length];
        Array.Copy(_data, arr, _data.Length);
        Array.Sort(arr);
        return arr;
    }
}