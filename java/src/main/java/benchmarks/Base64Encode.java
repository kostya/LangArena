package benchmarks;

import java.util.Base64;

public class Base64Encode extends Benchmark {
    private static final int TRIES = 8192;
    
    private int n;
    private String str;
    private String str2;
    private long result;
    
    public Base64Encode() {
        n = getIterations();
    }
    
    @Override
    public void prepare() {
        str = "a".repeat(n);
        str2 = Base64.getEncoder().encodeToString(str.getBytes());
    }
    
    @Override
    public void run() {
        long sEncoded = 0L;
        
        for (int i = 0; i < TRIES; i++) {
            String encoded = Base64.getEncoder().encodeToString(str.getBytes());
            sEncoded += encoded.length();
        }
        
        String message = String.format("encode %s... to %s...: %d\n", 
            str.substring(0, Math.min(4, str.length())),
            str2.substring(0, Math.min(4, str2.length())),
            sEncoded);
        
        result = Helper.checksum(message);
    }
    
    @Override
    public long getResult() {
        return result;
    }
}