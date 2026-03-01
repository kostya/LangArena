module benchmarks.distance;
import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.random;
import std.typecons;
import std.utf : byCodeUnit;
import benchmark;
import helper;

Tuple!(string, string)[] generatePairStrings(int n, int m)
{
    auto pairs = new Tuple!(string, string)[n];
    auto chars = "abcdefghij";

    foreach (i; 0 .. n)
    {
        int len1 = Helper.nextInt(m) + 4;
        int len2 = Helper.nextInt(m) + 4;

        auto str1 = new char[len1];
        auto str2 = new char[len2];

        foreach (j; 0 .. len1)
        {
            str1[j] = chars[Helper.nextInt(10)];
        }
        foreach (j; 0 .. len2)
        {
            str2[j] = chars[Helper.nextInt(10)];
        }

        pairs[i] = tuple(cast(string) str1, cast(string) str2);
    }

    return pairs;
}

class Jaro : Benchmark
{
private:
    long count;
    long size;
    Tuple!(string, string)[] pairs;
    uint resultVal;

protected:
    override string className() const
    {
        return "Distance::Jaro";
    }

public:
    this()
    {
        count = configVal("count");
        size = configVal("size");
        resultVal = 0;
    }

    override void prepare()
    {
        pairs = generatePairStrings(cast(int) count, cast(int) size);
    }

    private double jaro(string s1, string s2)
    {

        auto bytes1 = cast(ubyte[]) s1;
        auto bytes2 = cast(ubyte[]) s2;

        auto len1 = bytes1.length;
        auto len2 = bytes2.length;

        if (len1 == 0 || len2 == 0)
            return 0.0;

        auto matchDist = cast(int)(max(len1, len2) / 2) - 1;
        if (matchDist < 0)
            matchDist = 0;

        auto s1Matches = new bool[len1];
        auto s2Matches = new bool[len2];

        int matches = 0;
        foreach (i; 0 .. len1)
        {
            size_t start = i > matchDist ? i - matchDist : 0;
            size_t end = min(len2 - 1, i + matchDist);

            foreach (j; start .. end + 1)
            {
                if (!s2Matches[j] && bytes1[i] == bytes2[j])
                {
                    s1Matches[i] = true;
                    s2Matches[j] = true;
                    matches++;
                    break;
                }
            }
        }

        if (matches == 0)
            return 0.0;

        int transpositions = 0;
        size_t k = 0;
        foreach (i; 0 .. len1)
        {
            if (s1Matches[i])
            {
                while (k < len2 && !s2Matches[k])
                {
                    k++;
                }
                if (k < len2)
                {
                    if (bytes1[i] != bytes2[k])
                    {
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

    override void run(int iterationId)
    {
        foreach (pair; pairs)
        {
            double j = jaro(pair[0], pair[1]);
            uint val = cast(uint)(j * 1000);
            resultVal += val;
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class NGram : Benchmark
{
private:
    long count;
    long size;
    Tuple!(string, string)[] pairs;
    uint resultVal;
    enum int N = 4;

protected:
    override string className() const
    {
        return "Distance::NGram";
    }

public:
    this()
    {
        count = configVal("count");
        size = configVal("size");
        resultVal = 0;
    }

    override void prepare()
    {
        pairs = generatePairStrings(cast(int) count, cast(int) size);
    }

    private double ngram(string s1, string s2)
    {

        auto bytes1 = cast(ubyte[]) s1;
        auto bytes2 = cast(ubyte[]) s2;

        if (bytes1.length < N || bytes2.length < N)
            return 0.0;

        auto grams1 = new int[uint];

        for (int i = 0; i <= bytes1.length - N; i++)
        {
            uint gram = (cast(uint) bytes1[i] << 24) | (
                    cast(uint) bytes1[i + 1] << 16) | (
                    cast(uint) bytes1[i + 2] << 8) | cast(uint) bytes1[i + 3];

            grams1.require(gram, 0)++;
        }

        auto grams2 = new int[uint];
        int intersection = 0;

        for (int i = 0; i <= bytes2.length - N; i++)
        {
            uint gram = (cast(uint) bytes2[i] << 24) | (
                    cast(uint) bytes2[i + 1] << 16) | (
                    cast(uint) bytes2[i + 2] << 8) | cast(uint) bytes2[i + 3];

            grams2.require(gram, 0)++;

            if (auto count1 = gram in grams1)
            {
                if (grams2[gram] <= *count1)
                {
                    intersection++;
                }
            }
        }

        int total = cast(int) grams1.length + cast(int) grams2.length;
        return total > 0 ? cast(double) intersection / total : 0.0;
    }

    override void run(int iterationId)
    {
        foreach (pair; pairs)
        {
            resultVal += cast(uint)(ngram(pair[0], pair[1]) * 1000);
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
