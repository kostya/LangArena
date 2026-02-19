module benchmarks.fasta;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.random;
import benchmark;
import helper;

class Fasta : Benchmark
{
private:
    static struct Gene
    {
        char c;
        double prob;
    }

    enum LINE_LENGTH = 60;
    string resultStr;

    char selectRandom(Gene[] genelist)
    {
        double r = Helper.nextFloat();
        if (r < genelist[0].prob)
            return genelist[0].c;

        int lo = 0, hi = cast(int) genelist.length - 1;
        while (hi > lo + 1)
        {
            int i = (hi + lo) / 2;
            if (r < genelist[i].prob)
                hi = i;
            else
                lo = i;
        }
        return genelist[hi].c;
    }

    void makeRandomFasta(string id, string desc, Gene[] genelist, int nIter)
    {
        resultStr ~= ">" ~ id ~ " " ~ desc ~ "\n";
        int todo = nIter;

        while (todo > 0)
        {
            int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;
            char[] buffer = new char[m];

            foreach (i; 0 .. m)
            {
                buffer[i] = selectRandom(genelist);
            }

            resultStr ~= buffer.idup ~ "\n";
            todo -= LINE_LENGTH;
        }
    }

    void makeRepeatFasta(string id, string desc, string s, int nIter)
    {
        resultStr ~= ">" ~ id ~ " " ~ desc ~ "\n";
        int todo = nIter;
        size_t k = 0;
        size_t kn = s.length;

        while (todo > 0)
        {
            int m = (todo < LINE_LENGTH) ? todo : LINE_LENGTH;

            while (m >= cast(int)(kn - k))
            {
                resultStr ~= s[k .. $];
                m -= cast(int)(kn - k);
                k = 0;
            }

            resultStr ~= s[k .. k + m] ~ "\n";
            k += m;
            todo -= LINE_LENGTH;
        }
    }

protected:
    override string className() const
    {
        return "Fasta";
    }

public:
    int n;

    this()
    {
        n = configVal("n");
        resultStr = "";
    }

    override void run(int iterationId)
    {
        Gene[] IUB = [
            Gene('a', 0.27), Gene('c', 0.39), Gene('g', 0.51), Gene('t', 0.78),
            Gene('B', 0.8), Gene('D', 0.8200000000000001),
            Gene('H', 0.8400000000000001), Gene('K', 0.8600000000000001),
            Gene('M', 0.8800000000000001), Gene('N', 0.9000000000000001),
            Gene('R', 0.9200000000000002), Gene('S', 0.9400000000000002),
            Gene('V', 0.9600000000000002), Gene('W', 0.9800000000000002),
            Gene('Y', 1.0000000000000002)
        ];

        Gene[] HOMO = [
            Gene('a', 0.302954942668), Gene('c', 0.5009432431601),
            Gene('g', 0.6984905497992), Gene('t', 1.0)
        ];

        string ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

        makeRepeatFasta("ONE", "Homo sapiens alu", ALU, cast(int)(n * 2));
        makeRandomFasta("TWO", "IUB ambiguity codes", IUB, cast(int)(n * 3));
        makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, cast(int)(n * 5));
    }

    override uint checksum()
    {
        return Helper.checksum(resultStr);
    }

    string getResult() const
    {
        return resultStr;
    }
}
