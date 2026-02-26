package benchmarks;

import java.util.*;
import java.nio.charset.StandardCharsets;

public class Distance {

    public static class Pair {
        public final String s1;
        public final String s2;

        public Pair(String s1, String s2) {
            this.s1 = s1;
            this.s2 = s2;
        }
    }

    public static Pair[] generatePairStrings(long n, long m) {
        Pair[] pairs = new Pair[(int) n];
        char[] chars = "abcdefghij".toCharArray();

        for (int i = 0; i < n; i++) {
            int len1 = Helper.nextInt((int) m) + 4;
            int len2 = Helper.nextInt((int) m) + 4;

            StringBuilder sb1 = new StringBuilder(len1);
            StringBuilder sb2 = new StringBuilder(len2);

            for (int j = 0; j < len1; j++) {
                sb1.append(chars[Helper.nextInt(10)]);
            }
            for (int j = 0; j < len2; j++) {
                sb2.append(chars[Helper.nextInt(10)]);
            }

            pairs[i] = new Pair(sb1.toString(), sb2.toString());
        }

        return pairs;
    }

    public static class Jaro extends Benchmark {
        private long count;
        private long size;
        private Pair[] pairs;
        private long resultVal;

        public Jaro() {
            this.resultVal = 0L;
        }

        @Override
        public String name() {
            return "Distance::Jaro";
        }

        @Override
        public void prepare() {
            this.count = configVal("count");
            this.size = configVal("size");
            this.pairs = generatePairStrings(count, size);
            this.resultVal = 0L;
        }

        private double jaro(String s1, String s2) {
            byte[] bytes1 = s1.getBytes(StandardCharsets.US_ASCII);
            byte[] bytes2 = s2.getBytes(StandardCharsets.US_ASCII);

            int len1 = bytes1.length;
            int len2 = bytes2.length;

            if (len1 == 0 || len2 == 0) return 0.0;

            int matchDist = Math.max(len1, len2) / 2 - 1;
            if (matchDist < 0) matchDist = 0;

            boolean[] s1Matches = new boolean[len1];
            boolean[] s2Matches = new boolean[len2];

            int matches = 0;
            for (int i = 0; i < len1; i++) {
                int start = Math.max(0, i - matchDist);
                int end = Math.min(len2 - 1, i + matchDist);

                for (int j = start; j <= end; j++) {
                    if (!s2Matches[j] && bytes1[i] == bytes2[j]) {
                        s1Matches[i] = true;
                        s2Matches[j] = true;
                        matches++;
                        break;
                    }
                }
            }

            if (matches == 0) return 0.0;

            int transpositions = 0;
            int k = 0;
            for (int i = 0; i < len1; i++) {
                if (s1Matches[i]) {
                    while (k < len2 && !s2Matches[k]) {
                        k++;
                    }
                    if (k < len2) {
                        if (bytes1[i] != bytes2[k]) {
                            transpositions++;
                        }
                        k++;
                    }
                }
            }
            transpositions /= 2;

            double m = matches;
            return (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
        }

        @Override
        public void run(int iterationId) {
            for (Pair pair : pairs) {
                resultVal += (long) (jaro(pair.s1, pair.s2) * 1000);
            }
        }

        @Override
        public long checksum() {
            return resultVal;
        }
    }

    public static class NGram extends Benchmark {
        private long count;
        private long size;
        private Pair[] pairs;
        private long resultVal;
        private static final int N = 4;

        public NGram() {
            this.resultVal = 0L;
        }

        @Override
        public String name() {
            return "Distance::NGram";
        }

        @Override
        public void prepare() {
            this.count = configVal("count");
            this.size = configVal("size");
            this.pairs = generatePairStrings(count, size);
            this.resultVal = 0L;
        }

        private double ngram(String s1, String s2) {
            if (s1.length() < N || s2.length() < N) return 0.0;

            byte[] bytes1 = s1.getBytes(StandardCharsets.US_ASCII);
            byte[] bytes2 = s2.getBytes(StandardCharsets.US_ASCII);

            Map<Integer, Integer> grams1 = new HashMap<>(bytes1.length);

            for (int i = 0; i <= bytes1.length - N; i++) {
                int gram = ((int) bytes1[i] & 0xFF) << 24 |
                           ((int) bytes1[i + 1] & 0xFF) << 16 |
                           ((int) bytes1[i + 2] & 0xFF) << 8 |
                           ((int) bytes1[i + 3] & 0xFF);

                grams1.merge(gram, 1, Integer::sum);
            }

            Map<Integer, Integer> grams2 = new HashMap<>(bytes2.length);
            int intersection = 0;

            for (int i = 0; i <= bytes2.length - N; i++) {
                int gram = ((int) bytes2[i] & 0xFF) << 24 |
                           ((int) bytes2[i + 1] & 0xFF) << 16 |
                           ((int) bytes2[i + 2] & 0xFF) << 8 |
                           ((int) bytes2[i + 3] & 0xFF);

                grams2.merge(gram, 1, Integer::sum);

                Integer cnt1 = grams1.get(gram);
                if (cnt1 != null && grams2.get(gram) <= cnt1) {
                    intersection++;
                }
            }

            int total = grams1.size() + grams2.size();
            return total > 0 ? (double) intersection / total : 0.0;
        }

        @Override
        public void run(int iterationId) {
            for (Pair pair : pairs) {
                resultVal += (long) (ngram(pair.s1, pair.s2) * 1000);
            }
        }

        @Override
        public long checksum() {
            return resultVal;
        }
    }
}