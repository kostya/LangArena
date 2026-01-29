package benchmarks;

import java.util.*;

public class Decompression extends Compression {
    
    private CompressedData compressedData;
    private byte[] decompressed;
    
    public Decompression() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }
    
    @Override
    public String name() {
        return "Decompression";
    }
    
    @Override
    public void prepare() {
        testData = generateTestData(sizeVal);
        compressedData = compress(testData);
    }
    
    @Override
    public void run(int iterationId) {
        decompressed = decompress(compressedData);
        resultVal += decompressed.length;
    }
    
    @Override
    public long checksum() {
        long res = resultVal;
        if (Arrays.equals(testData, decompressed)) {
            res += 1000000;
        }
        return res;
    }
}