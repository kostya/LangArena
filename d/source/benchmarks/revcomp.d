module benchmarks.revcomp;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.range;
import benchmark;
import benchmarks.fasta;
import helper;
import core.atomic;

class Revcomp : Benchmark {
private:
    string input;
    shared uint checksumVal;

    string revcomp(string seq) {

        char[] reversed = seq.dup;
        reversed.reverse();

        ubyte[256] lookup;
        foreach (i; 0 .. 256) {
            lookup[i] = cast(ubyte)i;
        }

        string from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        string to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

        foreach (i, c; from) {
            lookup[cast(ubyte)c] = cast(ubyte)to[i];
        }

        foreach (ref c; reversed) {
            c = cast(char)lookup[cast(ubyte)c];
        }

        string result;
        for (size_t i = 0; i < reversed.length; i += 60) {
            size_t end = min(i + 60, reversed.length);
            result ~= reversed[i .. end].idup ~ "\n";
        }

        return result;
    }

protected:
    override string className() const { return "Revcomp"; }

public:
    this() {
        checksumVal = 0;
    }

    override void prepare() {
        auto fasta = new Fasta();
        fasta.n = configVal("n");
        fasta.run(0);
        string fastaResult = fasta.getResult();

        string seq;
        foreach (line; fastaResult.splitLines) {
            if (line.startsWith(">")) {
                seq ~= "\n---\n";
            } else {
                seq ~= line;
            }
        }

        input = seq;
    }

    override void run(int iterationId) {
        string resultStr = revcomp(input);
        atomicOp!"+="(checksumVal, Helper.checksum(resultStr));
    }

    override uint checksum() {
      return atomicLoad(checksumVal);
    }
}
