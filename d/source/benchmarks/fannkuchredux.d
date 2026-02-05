module benchmarks.fannkuchredux;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.typecons; 
import benchmark;
import helper;

class Fannkuchredux : Benchmark {
private:
    int n;
    uint resultVal;

protected:

    override string className() const { return "Fannkuchredux"; }

    auto fannkuchreduxImpl(int n) {
        int[] perm1 = new int[n];
        foreach (i; 0 .. n) perm1[i] = i;

        int[] perm = new int[n];
        int[] count = new int[n];
        int maxFlipsCount = 0, permCount = 0, checksum = 0;
        int r = n;

        while (true) {
            while (r > 1) {
                count[r - 1] = r;
                r--;
            }

            perm[] = perm1[];
            int flipsCount = 0;

            int k = perm[0];
            while (k != 0) {
                int k2 = (k + 1) >> 1;
                foreach (i; 0 .. k2) {
                    int j = k - i;
                    swap(perm[i], perm[j]);
                }
                flipsCount++;
                k = perm[0];
            }

            if (flipsCount > maxFlipsCount) maxFlipsCount = flipsCount;
            checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

            while (true) {
                if (r == n) return tuple(checksum, maxFlipsCount);

                int perm0 = perm1[0];
                foreach (i; 0 .. r) {
                    perm1[i] = perm1[i + 1];
                }
                perm1[r] = perm0;

                count[r]--;
                if (count[r] > 0) break;
                r++;
            }
            permCount++;
        }
    }

public:
    this() {
        n = configVal("n");
        resultVal = 0;
    }

    override void run(int iterationId) {
        auto result = fannkuchreduxImpl(cast(int)n);
        resultVal += cast(uint)(result[0] * 100 + result[1]);
    }

    override uint checksum() {
        return resultVal;
    }
}