package benchmarks;

import java.util.Base64;

public class Base64Encode extends Benchmark {
    private int n;
    private String str;
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
        str = "a".repeat(n);
        str2 = Base64.getEncoder().encodeToString(str.getBytes());
    }

    private String base64EncodeSimple(String input) {
        return Base64.getEncoder().encodeToString(input.getBytes());
    }

    @Override
    public void run(int iterationId) {

        str2 = base64EncodeSimple(str);
        resultVal = (resultVal + str2.length()) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        String prefix = str.length() > 4 ? str.substring(0, 4) + "..." : str;
        String prefix2 = str2.length() > 4 ? str2.substring(0, 4) + "..." : str2;
        String message = "encode " + prefix + " to " + prefix2 + ": " + resultVal;
        return Helper.checksum(message);
    }
}