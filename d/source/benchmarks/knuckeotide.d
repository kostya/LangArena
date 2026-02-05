module benchmarks.knuckeotide;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.format;
import std.typecons;
import benchmark;
import benchmarks.fasta;
import helper;

class Knuckeotide : Benchmark {
private:
    string seq;
    string resultStr;

    Tuple!(int, int[string]) frequency(string seq, int length) {  
        int n = cast(int)seq.length - length + 1;
        int[string] table;  

        foreach (i; 0 .. n) {
            string sub = seq[i .. i + length];
            if (sub in table) {
                table[sub]++;
            } else {
                table[sub] = 1;
            }
        }

        return tuple(n, table);
    }

    void sortByFreq(string seq, int length) {
        auto freq = frequency(seq, length);
        int n = freq[0];
        auto table = freq[1];

        auto pairs = table.byKeyValue.array;
        sort!((a, b) {
            if (a.value == b.value) return a.key < b.key;
            return a.value > b.value;
        })(pairs);

        foreach (pair; pairs) {
            double percent = (pair.value * 100.0) / n;  
            resultStr ~= pair.key.toUpper ~ " " ~ format("%.3f", percent) ~ "\n";
        }
        resultStr ~= "\n";
    }

    void findSeq(string seq, string s) {
        auto freq = frequency(seq, cast(int)s.length);
        auto table = freq[1];

        string sLower = s.toLower;
        int count = sLower in table ? table[sLower] : 0;

        resultStr ~= to!string(count) ~ "\t" ~ s.toUpper ~ "\n";
    }

protected:
    override string className() const { return "Knuckeotide"; }

public:
    this() {
        seq = "";
        resultStr = "";
    }

    override void prepare() {
        auto fasta = new Fasta();
        fasta.n = configVal("n");
        fasta.run(0);
        string res = fasta.getResult();

        bool three = false;
        seq = "";

        foreach (line; res.splitLines) {
            if (line.startsWith(">THREE")) {
                three = true;
                continue;
            }
            if (three) {
                seq ~= line;
            }
        }
    }

    override void run(int iterationId) {
        foreach (i; 1 .. 3) {
            sortByFreq(seq, i);
        }

        string[] searches = ["ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"];
        foreach (s; searches) {
            findSeq(seq, s);
        }
    }

    override uint checksum() {
        return Helper.checksum(resultStr);
    }
}