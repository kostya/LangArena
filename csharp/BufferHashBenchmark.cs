public abstract class BufferHashBenchmark : Benchmark
{
    protected byte[] _data;
    protected int _n;
    protected uint _result;

    protected BufferHashBenchmark()
    {
        _data = Array.Empty<byte>();
        _result = 0;
        _n = (int)ConfigVal("size");
    }

    public override void Prepare()
    {
        _data = new byte[_n];
        for (int i = 0; i < _data.Length; i++)
        {
            _data[i] = (byte)Helper.NextInt(256);
        }
    }

    protected abstract uint Test();

    public override void Run(long IterationId)
    {
        _result += Test();
    }

    public override uint Checksum => _result;
    public override string TypeName => "Hash";
}