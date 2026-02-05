package benchmarks;

import java.util.*;
import java.util.regex.Pattern;

public class RegexDna extends Benchmark {
    private String seq;
    private int ilen;
    private int clen;
    private StringBuilder result;
    private List<Pattern> compiledPatterns;

    public RegexDna() {
        result = new StringBuilder();
        compiledPatterns = new ArrayList<>();
    }

    @Override
    public String name() {
        return "RegexDna";
    }

    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = (int) configVal("n");
        fasta.run(0);
        String res = fasta.getResultString();

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

        compiledPatterns.clear();
        for (String pattern : patterns) {
            compiledPatterns.add(Pattern.compile(pattern));
        }
    }

    private int countPattern(int patternIdx) {
        Pattern pattern = compiledPatterns.get(patternIdx);
        java.util.regex.Matcher matcher = pattern.matcher(seq);
        int count = 0;
        while (matcher.find()) {
            count++;
        }
        return count;
    }

    @Override
    public void run(int iterationId) {
        for (int i = 0; i < compiledPatterns.size(); i++) {
            int count = countPattern(i);
            String pattern = compiledPatterns.get(i).pattern();
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
    public long checksum() {
        return Helper.checksum(result.toString());
    }

    public String getResultString() {
        return result.toString();
    }
}