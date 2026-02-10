package benchmarks;

public class Fannkuchredux extends Benchmark {
    private int n;
    private long resultVal;

    public Fannkuchredux() {
        n = (int) configVal("n");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Fannkuchredux";
    }

    private static class Result {
        int checksum;
        int maxFlips;

        Result(int checksum, int maxFlips) {
            this.checksum = checksum;
            this.maxFlips = maxFlips;
        }
    }

    private Result fannkuchredux(int n) {
        int[] perm1 = new int[32];
        int[] perm = new int[32];
        int[] count = new int[32];

        for (int i = 0; i < n; i++) {
            perm1[i] = i;
        }

        int maxFlipsCount = 0;
        int permCount = 0;
        int checksum = 0;
        int r = n;

        while (true) {
            while (r > 1) {
                count[r - 1] = r;
                r--;
            }

            System.arraycopy(perm1, 0, perm, 0, n);

            int flipsCount = 0;
            int k = perm[0];

            while (k != 0) {
                int k2 = (k + 1) >> 1;
                for (int i = 0; i < k2; i++) {
                    int j = k - i;
                    int temp = perm[i];
                    perm[i] = perm[j];
                    perm[j] = temp;
                }
                flipsCount++;
                k = perm[0];
            }

            if (flipsCount > maxFlipsCount) {
                maxFlipsCount = flipsCount;
            }

            if ((permCount & 1) == 0) {
                checksum += flipsCount;
            } else {
                checksum -= flipsCount;
            }

            while (true) {
                if (r == n) {
                    return new Result(checksum, maxFlipsCount);
                }

                int perm0 = perm1[0];
                for (int i = 0; i < r; i++) {
                    perm1[i] = perm1[i + 1];
                }
                perm1[r] = perm0;

                count[r]--;
                int cntr = count[r];
                if (cntr > 0) break;
                r++;
            }

            permCount++;
        }
    }

    @Override
    public void run(int iterationId) {
        Result res = fannkuchredux(n);
        resultVal += (res.checksum * 100L + res.maxFlips) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}