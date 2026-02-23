module benchmarks.base64encode;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.base64;
import benchmark;
import helper;

class Base64Encode : Benchmark
{
private:
    ubyte[] strBytes;
    string str2;
    uint resultVal;

protected:
    override string className() const
    {
        return "Base64::Encode";
    }

public:
    this()
    {
        resultVal = 0;
        int n = configVal("size");

        strBytes = new ubyte[n];
        strBytes[] = cast(ubyte) 'a';
        str2 = Base64.encode(strBytes).idup;
    }

    override void run(int iterationId)
    {
        str2 = Base64.encode(strBytes).idup;
        resultVal += cast(uint) str2.length;
    }

    override uint checksum()
    {
        string inputStr = replicate("a", strBytes.length);
        string debugStr = "encode " ~ (inputStr.length > 4
                ? "aaaa..." : inputStr) ~ " to " ~ (str2.length > 4
                ? str2[0 .. 4] ~ "..." : str2) ~ ": " ~ to!string(resultVal);
        return Helper.checksum(debugStr);
    }
}
