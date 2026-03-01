package benchmarks;

import java.util.Arrays;

public class Sieve extends Benchmark {
    private long limit;
    private long checksum;

    public Sieve() {
        limit = configVal("limit");
        checksum = 0L;
    }

    @Override
    public String name() {
        return "Etc::Sieve";
    }

    @Override
    public void run(int iterationId) {
        int lim = (int) limit;
        byte[] primes = new byte[lim + 1];
        Arrays.fill(primes, (byte) 1);
        primes[0] = 0;
        primes[1] = 0;

        int sqrtLimit = (int) Math.sqrt(lim);

        for (int p = 2; p <= sqrtLimit; p++) {
            if (primes[p] == 1) {
                for (int multiple = p * p; multiple <= lim; multiple += p) {
                    primes[multiple] = 0;
                }
            }
        }

        int lastPrime = 2;
        int count = 1;

        for (int n = 3; n <= lim; n += 2) {
            if (primes[n] == 1) {
                lastPrime = n;
                count++;
            }
        }

        checksum += (lastPrime + count);
    }

    @Override
    public long checksum() {
        return checksum;
    }
}