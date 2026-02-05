package benchmarks;

public class BufferHashSHA256 extends BufferHashBenchmark {

    private static class SimpleSHA256 {
        static byte[] digest(byte[] data) {
            byte[] result = new byte[32];

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
    public String name() {
        return "BufferHashSHA256";
    }

    @Override
    long test() {
        byte[] bytes = SimpleSHA256.digest(data);

        return ((bytes[3] & 0xFFL) << 24) |    
               ((bytes[2] & 0xFFL) << 16) |
               ((bytes[1] & 0xFFL) << 8) |
               (bytes[0] & 0xFFL);             
    }
}