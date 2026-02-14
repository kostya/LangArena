public class BufferHashSHA256 : BufferHashBenchmark
{
    protected override uint Test()
    {
        uint[] hashes = new uint[8]
        {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        };

        for (int i = 0; i < _data.Length; i++)
        {
            int hashIdx = i & 7;
            uint hash = hashes[hashIdx];
            byte b = _data[i];

            hash = ((hash << 5) + hash) + b;
            hash = (hash + (hash << 10)) ^ (hash >> 6);
            hashes[hashIdx] = hash;
        }

        byte[] result = new byte[32];
        for (int i = 0; i < 8; i++)
        {
            uint hash = hashes[i];
            result[i * 4] = (byte)(hash >> 24);
            result[i * 4 + 1] = (byte)(hash >> 16);
            result[i * 4 + 2] = (byte)(hash >> 8);
            result[i * 4 + 3] = (byte)hash;
        }

        return (uint)result[0] |
               ((uint)result[1] << 8) |
               ((uint)result[2] << 16) |
               ((uint)result[3] << 24);
    }
}