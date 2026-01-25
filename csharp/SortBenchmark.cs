using System.Text;

public abstract class SortBenchmark : Benchmark
{
    private const int ARR_SIZE = 100000;
    protected int _n;
    protected int[] _data;
    protected uint _result;
    
    public override long Result => _result;
    
    protected SortBenchmark()
    {
        _data = Array.Empty<int>();
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = GetType().Name;
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
            }
        }
        else
        {
            _n = 1;
        }
        
        // Генерируем данные
        _data = new int[ARR_SIZE];
        for (int i = 0; i < ARR_SIZE; i++)
        {
            _data[i] = Helper.NextInt(1000000);
        }
    }
    
    protected abstract int[] Test();
    
    protected string CheckNElements(int[] arr, int n)
    {
        var sb = new StringBuilder();
        sb.Append('[');
        
        int step = arr.Length / n;
        for (int index = 0; index < arr.Length; index += step)
        {
            sb.Append(index);
            sb.Append(':');
            sb.Append(arr[index]);
            sb.Append(',');
        }
        
        sb.Append(']');
        sb.Append('\n');
        return sb.ToString();
    }
    
    public override void Run()
    {
        string verify = CheckNElements(_data, 10);
        
        for (int i = 0; i < _n - 1; i++)
        {
            int[] t = Test();
            _result += (uint)t[t.Length / 2];
        }
        
        int[] arr = Test();
        verify += CheckNElements(_data, 10);
        verify += CheckNElements(arr, 10);
        
        unchecked
        {
            _result += Helper.Checksum(verify);
        }
    }
}