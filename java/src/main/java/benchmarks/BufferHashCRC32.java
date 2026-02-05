package benchmarks;

public class BufferHashCRC32 extends BufferHashBenchmark {

    @Override
    public String name() {
        return "BufferHashCRC32";
    }

    @Override
    long test() {
        int crc = 0xFFFFFFFF;

        for (byte b : data) {
            crc = crc ^ (b & 0xFF);
            for (int j = 0; j < 8; j++) {
                if ((crc & 1) != 0) {
                    crc = (crc >>> 1) ^ 0xEDB88320;
                } else {
                    crc = crc >>> 1;
                }
            }
        }

        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFFL;
    }
}