module benchmarks.base64decode;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.base64;
import std.exception;
import benchmark;
import helper;

class Base64Decode : Benchmark {
private:
    string str2;
    ubyte[] str3Bytes;
    uint resultVal;

protected:
    override string className() const { return "Base64Decode"; }

public:
    this() {
        resultVal = 0;
        int n = configVal("size");

        ubyte[] strBytes = new ubyte[n];
        strBytes[] = cast(ubyte)'a';

        char[] encodedChars = Base64.encode(strBytes);
        str2 = encodedChars.idup;

        try {
            str3Bytes = Base64.decode(encodedChars);
        } catch (Exception e) {
            str3Bytes = [];
            stderr.writeln("Base64 decode error: ", e.msg);
        }
    }

    override void run(int iterationId) {

        try {
            str3Bytes = Base64.decode(cast(char[])str2);  
            resultVal += cast(uint)str3Bytes.length;
        } catch (Exception e) {
            resultVal = 0;
        }
    }

    override uint checksum() {
        string str3 = cast(string)str3Bytes;

        string debugStr = "decode " ~ 
            (str2.length > 4 ? str2[0 .. 4] ~ "..." : str2) ~ 
            " to " ~ 
            (str3.length > 4 ? str3[0 .. 4] ~ "..." : str3) ~ 
            ": " ~ to!string(resultVal);
        return Helper.checksum(debugStr);
    }
}