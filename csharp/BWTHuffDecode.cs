public class BWTHuffDecode : BWTHuffEncode
{
    private CompressedData? _compressedData;
    private byte[] _decompressed = Array.Empty<byte>();

    public BWTHuffDecode()
    {
        _size = (int)ConfigVal("size");
    }

    public override void Prepare()
    {
        _testData = GenerateTestData(_size);
        _compressedData = Compress(_testData);
    }

    public override void Run(long IterationId)
    {
        if (_compressedData != null)
        {
            _decompressed = Decompress(_compressedData);
            _result += (uint)_decompressed.Length;
        }
    }

    public override uint Checksum
    {
        get
        {
            uint res = _result;
            if (_testData.SequenceEqual(_decompressed)) res += 1000000;
            return res;
        }
    }
}