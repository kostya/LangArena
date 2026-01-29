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
    public String name() {
        return "Revcomp";
    }
    
    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = (int) configVal("n");
        fasta.run(0);
        
        String fastaResult = fasta.getResultString();
        
        StringBuilder seq = new StringBuilder();
        for (String line : fastaResult.split("\n")) {
            if (line.startsWith(">")) {
                seq.append("\n---\n");
            } else {
                seq.append(line);
            }
        }
        
        input = seq.toString();
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
    public void run(int iterationId) {
        result.append(revcompString(input));
    }
    
    private String revcompString(String seq) {
        StringBuilder reversed = new StringBuilder(seq).reverse();
        for (int i = 0; i < reversed.length(); i++) {
            char c = reversed.charAt(i);
            reversed.setCharAt(i, COMPLEMENT.getOrDefault(c, c));
        }
        
        StringBuilder resultStr = new StringBuilder();
        int stringLen = reversed.length();
        for (int i = 0; i < stringLen; i += 60) {
            int end = Math.min(i + 60, stringLen);
            resultStr.append(reversed.substring(i, end)).append("\n");
        }
        return resultStr.toString();
    }
    
    @Override
    public long checksum() {
        return Helper.checksum(result.toString());
    }
}