module benchmarks.regexdna;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.regex;
import benchmark;
import benchmarks.fasta;
import helper;

class RegexDna : Benchmark
{
private:
    string seq;
    int ilen, clen;
    string resultStr;

    static immutable string[] PATTERNS = [
        "agggtaaa|tttaccct", "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t", "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct"
    ];

    static struct Replacement
    {
        char from;
        string to;
    }

    static immutable Replacement[] REPLACEMENTS = [
        Replacement('B', "(c|g|t)"), Replacement('D', "(a|g|t)"),
        Replacement('H', "(a|c|t)"), Replacement('K', "(g|t)"),
        Replacement('M', "(a|c)"), Replacement('N', "(a|c|g|t)"),
        Replacement('R', "(a|g)"), Replacement('S', "(c|t)"),
        Replacement('V', "(a|c|g)"), Replacement('W', "(a|t)"),
        Replacement('Y', "(c|t)")
    ];

protected:
    override string className() const
    {
        return "CLBG::RegexDna";
    }

public:
    this()
    {
        ilen = 0;
        clen = 0;
        resultStr = "";
    }

    override void prepare()
    {
        auto fasta = new Fasta();
        fasta.n = configVal("n");
        fasta.run(0);
        string res = fasta.getResult();

        seq = "";
        ilen = 0;

        foreach (line; res.splitLines)
        {
            ilen += cast(int) line.length + 1;
            if (line.length > 0 && line[0] != '>')
            {
                seq ~= line;
            }
        }

        clen = cast(int) seq.length;
    }

    override void run(int iterationId)
    {

        foreach (pattern; PATTERNS)
        {
            auto re = regex(pattern, "g");
            auto matches = matchAll(seq, re);
            size_t count = 0;
            foreach (match; matches)
            {
                count++;
            }

            resultStr ~= pattern ~ " " ~ to!string(count) ~ "\n";
        }

        string seq2;
        foreach (c; seq)
        {
            bool replaced = false;
            foreach (repl; REPLACEMENTS)
            {
                if (c == repl.from)
                {
                    seq2 ~= repl.to;
                    replaced = true;
                    break;
                }
            }
            if (!replaced)
            {
                seq2 ~= c;
            }
        }

        resultStr ~= "\n" ~ to!string(ilen) ~ "\n";
        resultStr ~= to!string(clen) ~ "\n";
        resultStr ~= to!string(seq2.length) ~ "\n";
    }

    override uint checksum()
    {
        return Helper.checksum(resultStr);
    }
}
