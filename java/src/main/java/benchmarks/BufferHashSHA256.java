package benchmarks;

public class BufferHashSHA256 extends BufferHashBenchmark {
    
    private static class SimpleSHA256 {
        static byte[] digest(byte[] data) {
            byte[] result = new byte[32];
            
            // Используем 8 разных начальных хешей (как в SHA-256)
            int[] hashes = new int[] {
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
            };
            
            for (int i = 0; i < data.length; i++) {
                int hashIdx = i % 8;
                int hash = hashes[hashIdx];
                hash = ((hash << 5) + hash) + (data[i] & 0xFF);
                hash = (hash + (hash << 10)) ^ (hash >>> 6);
                hashes[hashIdx] = hash;
            }
            
            // Записываем все 8 хешей по 4 байта каждый
            for (int i = 0; i < 8; i++) {
                int hash = hashes[i];
                result[i * 4] = (byte) (hash >>> 24);
                result[i * 4 + 1] = (byte) (hash >>> 16);
                result[i * 4 + 2] = (byte) (hash >>> 8);
                result[i * 4 + 3] = (byte) hash;
            }
            
            return result;
        }
    }
    
    @Override
    long test() {
        byte[] bytes = SimpleSHA256.digest(data);
        
        // C++: записывает big-endian байты, читает как little-endian uint32
        // На little-endian системе это эквивалентно reverseBytes
        
        // Способ 1: читаем байты в little-endian порядке
        return ((bytes[3] & 0xFFL) << 24) |    // младший байт становится старшим
               ((bytes[2] & 0xFFL) << 16) |
               ((bytes[1] & 0xFFL) << 8) |
               (bytes[0] & 0xFFL);             // старший байт становится младшим
        
        // Или проще: используем ByteBuffer
        // java.nio.ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).getInt()
    }
}