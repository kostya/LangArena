package benchmarks;

import java.util.Base64;

public class Base64Decode extends Benchmark {
    private static final int TRIES = 8192;
    
    private int n;
    private String str2;
    private String str3;
    private long result;
    
    public Base64Decode() {
        n = getIterations();
    }
    
    @Override
    public void prepare() {
        String str = "a".repeat(n);
        str2 = Base64.getEncoder().encodeToString(str.getBytes());
        str3 = new String(Base64.getDecoder().decode(str2));
    }
    
    @Override
    public void run() {
        long sDecoded = 0L;
        
        for (int i = 0; i < TRIES; i++) {
            String decoded = new String(Base64.getDecoder().decode(str2));
            sDecoded += decoded.length();
        }
        
        String message = String.format("decode %s... to %s...: %d\n", 
            str2.substring(0, Math.min(4, str2.length())),
            str3.substring(0, Math.min(4, str3.length())),
            sDecoded);
        
        result = Helper.checksum(message);
    }
    
    @Override
    public long getResult() {
        return result;
    }
}