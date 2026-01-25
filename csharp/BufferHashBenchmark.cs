public abstract class BufferHashBenchmark : Benchmark
{
    protected byte[] _data;
    protected int _n;
    protected uint _result;
    
    public override long Result => _result;
    
    protected BufferHashBenchmark()
    {
        _data = Array.Empty<byte>();
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
        
        // Генерируем случайные данные
        _data = new byte[1000000];
        for (int i = 0; i < _data.Length; i++)
        {
            _data[i] = (byte)Helper.NextInt(256);
        }
    }
    
    protected abstract uint Test();
    
    public override void Run()
    {
        for (int i = 0; i < _n; i++)
        {
            unchecked
            {
                _result += Test();
            }
        }
    }
}