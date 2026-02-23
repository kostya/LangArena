package benchmarks;

import java.util.Base64;
import java.nio.charset.StandardCharsets;

public class Base64Decode extends Benchmark {
    private int n;
    private String str2;
    private byte[] bytes;
    private long resultVal;

    public Base64Decode() {
        n = (int) configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Base64::Decode";
    }

    @Override
    public void prepare() {
        String str = "a".repeat(n);
        str2 = Base64.getEncoder().encodeToString(str.getBytes());
        bytes = Base64.getDecoder().decode(str2);
    }

    @Override
    public void run(int iterationId) {
        bytes = Base64.getDecoder().decode(str2);
        resultVal = (resultVal + bytes.length) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        String str3 = new String(bytes, 0, 5, StandardCharsets.UTF_8);
        String prefix2 = str2.length() > 4 ? str2.substring(0, 4) + "..." : str2;
        String prefix3 = str3.length() > 4 ? str3.substring(0, 4) + "..." : str3;
        String message = "decode " + prefix2 + " to " + prefix3 + ": " + resultVal;
        return Helper.checksum(message);
    }
}