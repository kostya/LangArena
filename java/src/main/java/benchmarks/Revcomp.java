package benchmarks;

import java.util.HashMap;
import java.util.Map;

public class Revcomp extends Benchmark {
    private String input;
    private StringBuilder result;
    private static final Map<Character, Character> COMPLEMENT = new HashMap<>();
    
    static {
        String from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        String to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";
        for (int i = 0; i < from.length(); i++) {
            COMPLEMENT.put(from.charAt(i), to.charAt(i));
        }
    }
    
    public Revcomp() {
        result = new StringBuilder();
    }
    
    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = getIterations();
        fasta.run();
        input = fasta.result.toString(); // Нужно добавить метод getOutput() в Fasta
    }
    
    private void revcomp(String seq) {
        StringBuilder reversed = new StringBuilder(seq).reverse();
        for (int i = 0; i < reversed.length(); i++) {
            char c = reversed.charAt(i);
            reversed.setCharAt(i, COMPLEMENT.getOrDefault(c, c));
        }
        
        int stringLen = reversed.length();
        for (int i = 0; i < stringLen; i += 60) {
            int end = Math.min(i + 60, stringLen);
            result.append(reversed.substring(i, end)).append("\n");
        }
    }
    
    @Override
    public void run() {
        result.setLength(0);
        StringBuilder seq = new StringBuilder();
        
        for (String line : input.split("\n")) {
            if (line.startsWith(">")) {
                if (seq.length() > 0) {
                    revcomp(seq.toString());
                    seq.setLength(0);
                }
                result.append(line).append("\n");
            } else {
                seq.append(line.trim());
            }
        }
        
        if (seq.length() > 0) {
            revcomp(seq.toString());
        }
    }
    
    @Override
    public long getResult() {
        return Helper.checksum(result.toString());
    }
}