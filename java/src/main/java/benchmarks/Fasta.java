package benchmarks;

import java.io.ByteArrayOutputStream;
import java.util.*;

public class Fasta extends Benchmark {
    private static final int LINE_LENGTH = 60;

    private static class Gene {
        char ch;
        double prob;

        Gene(char ch, double prob) {
            this.ch = ch;
            this.prob = prob;
        }
    }

    private static final Gene[] IUB = {
        new Gene('a', 0.27), new Gene('c', 0.39), new Gene('g', 0.51),
        new Gene('t', 0.78), new Gene('B', 0.8), new Gene('D', 0.8200000000000001),
        new Gene('H', 0.8400000000000001), new Gene('K', 0.8600000000000001),
        new Gene('M', 0.8800000000000001), new Gene('N', 0.9000000000000001),
        new Gene('R', 0.9200000000000002), new Gene('S', 0.9400000000000002),
        new Gene('V', 0.9600000000000002), new Gene('W', 0.9800000000000002),
        new Gene('Y', 1.0000000000000002)
    };

    private static final Gene[] HOMO = {
        new Gene('a', 0.302954942668), new Gene('c', 0.5009432431601),
        new Gene('g', 0.6984905497992), new Gene('t', 1.0)
    };

    private static final String ALU = 
        "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

    public int n;
    public ByteArrayOutputStream result;

    public Fasta() {
        n = (int) configVal("n");
        result = new ByteArrayOutputStream();
    }

    @Override
    public String name() {
        return "Fasta";
    }

    private char selectRandom(Gene[] genelist) {
        double r = Helper.nextFloat();
        if (r < genelist[0].prob) return genelist[0].ch;

        int lo = 0;
        int hi = genelist.length - 1;

        while (hi > lo + 1) {
            int i = (hi + lo) / 2;
            if (r < genelist[i].prob) {
                hi = i;
            } else {
                lo = i;
            }
        }
        return genelist[hi].ch;
    }

    private void makeRandomFasta(String id, String desc, Gene[] genelist, int n) {
        try {
            result.write((">" + id + " " + desc + "\n").getBytes());

            int todo = n;
            char[] buffer = new char[LINE_LENGTH];

            while (todo > 0) {
                int m = Math.min(todo, LINE_LENGTH);

                for (int i = 0; i < m; i++) {
                    buffer[i] = selectRandom(genelist);
                }

                result.write(new String(buffer, 0, m).getBytes());
                result.write('\n');
                todo -= LINE_LENGTH;
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private void makeRepeatFasta(String id, String desc, String s, int n) {
        try {
            result.write((">" + id + " " + desc + "\n").getBytes());

            int todo = n;
            int k = 0;
            int kn = s.length();

            while (todo > 0) {
                int m = Math.min(todo, LINE_LENGTH);

                while (m >= kn - k) {
                    result.write(s.substring(k).getBytes());
                    m -= kn - k;
                    k = 0;
                }

                if (m > 0) {
                    result.write(s.substring(k, k + m).getBytes());
                    k += m;
                }

                result.write('\n');
                todo -= LINE_LENGTH;
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void run(int iterationId) {
        makeRepeatFasta("ONE", "Homo sapiens alu", ALU, n * 2);
        makeRandomFasta("TWO", "IUB ambiguity codes", IUB, n * 3);
        makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, n * 5);
    }

    @Override
    public long checksum() {
        return Helper.checksum(result.toByteArray());
    }

    public String getResultString() {
        return result.toString();
    }
}