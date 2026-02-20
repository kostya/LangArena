package benchmarks;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class Knuckeotide extends Benchmark {
    private String seq;
    private ByteArrayOutputStream result;
    private static final String NL = "\n";

    public Knuckeotide() {
        result = new ByteArrayOutputStream();
    }

    @Override
    public String name() {
        return "Knuckeotide";
    }

    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = (int) configVal("n");
        fasta.run(0);

        String fastaOutput = fasta.getResultString();

        StringBuilder seqBuilder = new StringBuilder();
        boolean afterThree = false;

        String[] lines = fastaOutput.split("\n");
        for (String line : lines) {
            if (line.startsWith(">THREE")) {
                afterThree = true;
                continue;
            }

            if (afterThree) {
                if (line.startsWith(">")) {
                    break;
                }
                seqBuilder.append(line.trim());
            }
        }

        seq = seqBuilder.toString();
    }

    private static class FreqResult {
        int n;
        Map<String, Integer> table;

        FreqResult(int n, Map<String, Integer> table) {
            this.n = n;
            this.table = table;
        }
    }

    private FreqResult frequency(String seq, int length) {
        int n = seq.length() - length + 1;
        if (n <= 0) {
            return new FreqResult(0, new HashMap<>());
        }

        Map<String, Integer> table = new HashMap<>();

        for (int i = 0; i < n; i++) {
            String sub = seq.substring(i, i + length);
            table.put(sub, table.getOrDefault(sub, 0) + 1);
        }

        return new FreqResult(n, table);
    }

    private void sortByFreq(String seq, int length) {
        try {
            FreqResult fr = frequency(seq, length);
            List<Map.Entry<String, Integer>> entries = new ArrayList<>(fr.table.entrySet());

            entries.sort((a, b) -> {
                int cmp = b.getValue().compareTo(a.getValue());
                if (cmp != 0) return cmp;
                return a.getKey().compareTo(b.getKey());
            });

            for (Map.Entry<String, Integer> entry : entries) {
                double freq = (entry.getValue() * 100.0) / fr.n;

                String line = String.format(Locale.US, "%s %.3f%s",
                                            entry.getKey().toUpperCase(), freq, NL);
                result.write(line.getBytes(StandardCharsets.UTF_8));
            }

            result.write(NL.getBytes(StandardCharsets.UTF_8));

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private void findSeq(String seq, String pattern) {
        try {
            String patternLower = pattern.toLowerCase();
            FreqResult fr = frequency(seq, patternLower.length());
            int count = fr.table.getOrDefault(patternLower, 0);

            String line = count + "\t" + pattern.toUpperCase() + NL;
            result.write(line.getBytes(StandardCharsets.UTF_8));

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void run(int iterationId) {
        for (int i = 1; i <= 2; i++) {
            sortByFreq(seq, i);
        }

        String[] patterns = {"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"};
        for (String pattern : patterns) {
            findSeq(seq, pattern);
        }
    }

    @Override
    public long checksum() {
        String output = result.toString(StandardCharsets.UTF_8);
        return Helper.checksum(output);
    }

    public String getResultString() {
        return result.toString(StandardCharsets.UTF_8);
    }
}