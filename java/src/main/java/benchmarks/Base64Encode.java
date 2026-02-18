package benchmarks;

import java.util.Base64;
import java.nio.charset.StandardCharsets;

public class Base64Encode extends Benchmark {
    private int n;
    private byte[] bytes;
    private String str2;
    private long resultVal;

    public Base64Encode() {
        n = (int) configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Base64Encode";
    }

    @Override
    public void prepare() {
        String str = "a".repeat(n);
        bytes = str.getBytes();
        str2 = Base64.getEncoder().encodeToString(bytes);
    }

    @Override
    public void run(int iterationId) {
        str2 = Base64.getEncoder().encodeToString(bytes);
        resultVal = (resultVal + str2.length()) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        String str = new String(bytes, 0, 5, StandardCharsets.UTF_8);
        String prefix = str.length() > 4 ? str.substring(0, 4) + "..." : str;
        String prefix2 = str2.length() > 4 ? str2.substring(0, 4) + "..." : str2;
        String message = "encode " + prefix + " to " + prefix2 + ": " + resultVal;
        return Helper.checksum(message);
    }
}