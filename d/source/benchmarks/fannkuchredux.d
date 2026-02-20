module benchmarks.fannkuchredux;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.typecons;
import std.range;
import benchmark;
import helper;

class Fannkuchredux : Benchmark
{
private:
    int n;
    uint resultVal;

protected:

    override string className() const
    {
        return "Fannkuchredux";
    }

    auto fannkuchreduxImpl(int n)
    {
        int[32] perm1_static;
        int[32] perm_static;
        int[32] count_static;

        int[] perm1 = perm1_static[0 .. n];
        int[] perm = perm_static[0 .. n];
        int[] count = count_static[0 .. n];

        foreach (i; 0 .. n)
            perm1[i] = i;
        int maxFlipsCount = 0, permCount = 0, checksum = 0;
        int r = n;

        while (true)
        {
            while (r > 1)
            {
                count[r - 1] = r;
                r--;
            }

            perm[] = perm1[];
            int flipsCount = 0;

            int k = perm[0];
            while (k != 0)
            {

                int i = 0;
                int j = k;
                while (i < j)
                {
                    swap(perm[i], perm[j]);
                    i++;
                    j--;
                }
                flipsCount++;
                k = perm[0];
            }

            maxFlipsCount = max(maxFlipsCount, flipsCount);
            checksum += (permCount & 1) == 0 ? flipsCount : -flipsCount;

            while (true)
            {
                if (r == n)
                    return tuple(checksum, maxFlipsCount);

                int first = perm1[0];
                foreach (i; 0 .. r)
                {
                    perm1[i] = perm1[i + 1];
                }
                perm1[r] = first;

                if (--count[r] > 0)
                    break;
                r++;
            }
            permCount++;
        }
    }

public:
    this()
    {
        n = configVal("n");
        resultVal = 0;
    }

    override void run(int iterationId)
    {
        auto result = fannkuchreduxImpl(cast(int) n);
        resultVal += cast(uint)(result[0] * 100 + result[1]);
    }

    override uint checksum()
    {
        return resultVal;
    }
}
