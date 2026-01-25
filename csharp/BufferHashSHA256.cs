public class BufferHashSHA256 : BufferHashBenchmark
{
    protected override uint Test()
    {
        // Упрощенный SHA-256 как в Crystal версии
        uint[] hashes = new uint[8]
        {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        };
        
        for (int i = 0; i < _data.Length; i++)
        {
            int hashIdx = i % 8;
            uint hash = hashes[hashIdx];
            byte b = _data[i];
            
            unchecked
            {
                hash = ((hash << 5) + hash) + b;
                hash = (hash + (hash << 10)) ^ (hash >> 6);
                hashes[hashIdx] = hash;
            }
        }
        
        // Эмуляция C++: преобразуем первый хеш в байты big-endian и обратно
        uint firstHash = hashes[0];
        byte[] bytes = new byte[4];
        bytes[0] = (byte)(firstHash >> 24);
        bytes[1] = (byte)(firstHash >> 16);
        bytes[2] = (byte)(firstHash >> 8);
        bytes[3] = (byte)firstHash;
        
        // На little-endian системе это будет другое значение
        return BitConverter.ToUInt32(bytes, 0);
    }
}