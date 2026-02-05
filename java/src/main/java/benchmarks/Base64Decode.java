package benchmarks;

import java.util.Base64;

public class Base64Decode extends Benchmark {
    private int n;
    private String str2;
    private String str3;
    private long resultVal;

    public Base64Decode() {
        n = (int) configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Base64Decode";
    }

    @Override
    public void prepare() {
        String str = "a".repeat(n);
        str2 = Base64.getEncoder().encodeToString(str.getBytes());
        str3 = new String(Base64.getDecoder().decode(str2));
    }

    private String base64DecodeSimple(String input) {
        return new String(Base64.getDecoder().decode(input));
    }

    @Override
    public void run(int iterationId) {

        str3 = base64DecodeSimple(str2);
        resultVal = (resultVal + str3.length()) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        String prefix2 = str2.length() > 4 ? str2.substring(0, 4) + "..." : str2;
        String prefix3 = str3.length() > 4 ? str3.substring(0, 4) + "..." : str3;
        String message = "decode " + prefix2 + " to " + prefix3 + ": " + resultVal;
        return Helper.checksum(message);
    }
}