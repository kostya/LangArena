public class BufferHashCRC32 : BufferHashBenchmark
{
    protected override uint Test()
    {
        uint crc = 0xFFFFFFFF;

        foreach (byte b in _data)
        {
            crc ^= b;
            for (int j = 0; j < 8; j++)
            {
                if ((crc & 1) != 0) crc = (crc >> 1) ^ 0xEDB88320;
                else crc >>= 1;
            }
        }

        return crc ^ 0xFFFFFFFF;
    }
    public override string TypeName => "Hash::CRC32";
}