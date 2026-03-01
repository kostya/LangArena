using System;
using System.Collections.Generic;
using System.Text;

public static class StringGenerator
{
    private static readonly char[] Chars = "abcdefghij".ToCharArray();

    public static (string, string)[] GeneratePairStrings(long count, long size)
    {
        var pairs = new (string, string)[count];

        for (long i = 0; i < count; i++)
        {
            int len1 = Helper.NextInt((int)size) + 4;
            int len2 = Helper.NextInt((int)size) + 4;

            var sb1 = new StringBuilder(len1);
            var sb2 = new StringBuilder(len2);

            for (int j = 0; j < len1; j++)
            {
                sb1.Append(Chars[Helper.NextInt(10)]);
            }
            for (int j = 0; j < len2; j++)
            {
                sb2.Append(Chars[Helper.NextInt(10)]);
            }

            pairs[i] = (sb1.ToString(), sb2.ToString());
        }

        return pairs;
    }
}

public class Jaro : Benchmark
{
    private long _count;
    private long _size;
    private (string, string)[] _pairs;
    private uint _result;

    public Jaro()
    {
        _count = ConfigVal("count");
        _size = ConfigVal("size");
        _result = 0;
    }

    public override void Prepare()
    {
        _pairs = StringGenerator.GeneratePairStrings(_count, _size);
    }

    private double CalcJaro(string s1, string s2)
    {

        byte[] bytes1 = Encoding.ASCII.GetBytes(s1);
        byte[] bytes2 = Encoding.ASCII.GetBytes(s2);

        int len1 = bytes1.Length;
        int len2 = bytes2.Length;

        if (len1 == 0 || len2 == 0) return 0.0;

        int matchDist = Math.Max(len1, len2) / 2 - 1;
        if (matchDist < 0) matchDist = 0;

        var s1Matches = new bool[len1];
        var s2Matches = new bool[len2];

        int matches = 0;
        for (int i = 0; i < len1; i++)
        {
            int start = Math.Max(0, i - matchDist);
            int end = Math.Min(len2 - 1, i + matchDist);

            for (int j = start; j <= end; j++)
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

        if (matches == 0) return 0.0;

        int transpositions = 0;
        int k = 0;
        for (int i = 0; i < len1; i++)
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

    public override void Run(long iterationId)
    {
        foreach (var pair in _pairs)
        {
            _result += (uint)(CalcJaro(pair.Item1, pair.Item2) * 1000);
        }
    }

    public override uint Checksum => _result;
    public override string TypeName => "Distance::Jaro";
}

public class NGram : Benchmark
{
    private long _count;
    private long _size;
    private (string, string)[] _pairs;
    private uint _result;
    private const int N = 4;

    public NGram()
    {
        _count = ConfigVal("count");
        _size = ConfigVal("size");
        _result = 0;
    }

    public override void Prepare()
    {
        _pairs = StringGenerator.GeneratePairStrings(_count, _size);
    }

    private double CalcNGram(string s1, string s2)
    {

        byte[] bytes1 = Encoding.ASCII.GetBytes(s1);
        byte[] bytes2 = Encoding.ASCII.GetBytes(s2);

        if (bytes1.Length < N || bytes2.Length < N) return 0.0;

        var grams1 = new Dictionary<uint, int>(bytes1.Length);

        for (int i = 0; i <= bytes1.Length - N; i++)
        {
            uint gram = ((uint)bytes1[i] << 24) |
                       ((uint)bytes1[i + 1] << 16) |
                       ((uint)bytes1[i + 2] << 8) |
                        (uint)bytes1[i + 3];

            grams1.TryGetValue(gram, out int count);
            grams1[gram] = count + 1;
        }

        var grams2 = new Dictionary<uint, int>(bytes2.Length);
        int intersection = 0;

        for (int i = 0; i <= bytes2.Length - N; i++)
        {
            uint gram = ((uint)bytes2[i] << 24) |
                       ((uint)bytes2[i + 1] << 16) |
                       ((uint)bytes2[i + 2] << 8) |
                        (uint)bytes2[i + 3];

            grams2.TryGetValue(gram, out int count2);
            grams2[gram] = count2 + 1;

            if (grams1.TryGetValue(gram, out int count1) && grams2[gram] <= count1)
            {
                intersection++;
            }
        }

        int total = grams1.Count + grams2.Count;
        return total > 0 ? (double)intersection / total : 0.0;
    }

    public override void Run(long iterationId)
    {
        foreach (var pair in _pairs)
        {
            _result += (uint)(CalcNGram(pair.Item1, pair.Item2) * 1000);
        }
    }

    public override uint Checksum => _result;
    public override string TypeName => "Distance::NGram";
}