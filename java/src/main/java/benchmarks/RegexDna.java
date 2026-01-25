package benchmarks;

import java.util.*;
import java.util.regex.Pattern;

public class RegexDna extends Benchmark {
    private String seq;
    private int ilen;
    private int clen;
    private StringBuilder result;
    
    public RegexDna() {
        result = new StringBuilder();
    }
    
    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = getIterations();
        fasta.run();
        String res = fasta.result.toString(); // Нужно добавить метод getOutput() в Fasta

        StringBuilder seqBuilder = new StringBuilder();
        ilen = 0;
        clen = 0;
        
        for (String line : res.split("\n")) {
            ilen += line.length() + 1;
            if (!line.startsWith(">")) {
                seqBuilder.append(line.trim());
                clen += line.trim().length();
            }
        }
        
        seq = seqBuilder.toString();
    }
    
    @Override
    public void run() {
        result.setLength(0);
        
        String[] patterns = {
            "agggtaaa|tttaccct",
            "[cgt]gggtaaa|tttaccc[acg]",
            "a[act]ggtaaa|tttacc[agt]t",
            "ag[act]gtaaa|tttac[agt]ct",
            "agg[act]taaa|ttta[agt]cct",
            "aggg[acg]aaa|ttt[cgt]ccct",
            "agggt[cgt]aa|tt[acg]accct",
            "agggta[cgt]a|t[acg]taccct",
            "agggtaa[cgt]|[acg]ttaccct"
        };
        
        for (String pattern : patterns) {
            Pattern p = Pattern.compile(pattern);
            java.util.regex.Matcher m = p.matcher(seq);
            int count = 0;
            while (m.find()) {
                count++;
            }
            result.append(pattern).append(" ").append(count).append("\n");
        }
        
        Map<String, String> replacements = new HashMap<>();
        replacements.put("B", "(c|g|t)");
        replacements.put("D", "(a|g|t)");
        replacements.put("H", "(a|c|t)");
        replacements.put("K", "(g|t)");
        replacements.put("M", "(a|c)");
        replacements.put("N", "(a|c|g|t)");
        replacements.put("R", "(a|g)");
        replacements.put("S", "(c|t)");
        replacements.put("V", "(a|c|g)");
        replacements.put("W", "(a|t)");
        replacements.put("Y", "(c|t)");
        
        String newSeq = seq;
        for (Map.Entry<String, String> entry : replacements.entrySet()) {
            newSeq = newSeq.replaceAll(entry.getKey(), entry.getValue());
        }
        
        result.append("\n");
        result.append(ilen).append("\n");
        result.append(clen).append("\n");
        result.append(newSeq.length()).append("\n");
    }
    
    @Override
    public long getResult() {
        return Helper.checksum(result.toString());
    }
    
    // Helper method to get result as string for Fasta
    private String getResultString() {
        return result.toString();
    }
}