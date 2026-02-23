using System.Text;

public abstract class SortBenchmark : Benchmark
{
    protected int[] _data;
    protected long _size;
    protected uint _result;

    protected SortBenchmark()
    {
        _data = Array.Empty<int>();
        _result = 0;
        _size = ConfigVal("size");
    }

    public override void Prepare()
    {
        _data = new int[_size];
        for (int i = 0; i < _size; i++) _data[i] = Helper.NextInt(1000000);
    }

    protected abstract int[] Test();

    public override void Run(long IterationId)
    {
        _result += (uint)_data[Helper.NextInt((int)_size)];
        int[] t = Test();
        _result += (uint)t[Helper.NextInt((int)_size)];
    }

    public override uint Checksum => _result;
    public override string TypeName => "Sort";
}