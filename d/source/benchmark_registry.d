module benchmark_registry;

import std.stdio;
import std.string;
import std.meta;
import benchmark;

template registerAllBenchmarks(Benchmarks...)
{

    string generateCasesCode()
    {
        string code;
        static foreach (bench; Benchmarks)
        {

            {
                string name = __traits(identifier, bench);
                string lowerName = name.toLower;
                code ~= "case \"" ~ lowerName ~ "\": return new " ~ name ~ "();\n";
            }
        }
        return code;
    }

    string generateNameListCode()
    {
        string code = "string[] names;\n";
        static foreach (bench; Benchmarks)
        {
            {
                string name = __traits(identifier, bench);
                code ~= "names ~= \"" ~ name ~ "\";\n";
            }
        }
        code ~= "return names;";
        return code;
    }

    enum registerAllBenchmarks = "string[] getAllBenchmarkNames() {\n" ~ generateNameListCode() ~ "\n" ~ "}\n\n" ~ "Benchmark createBenchmark(string name) {\n"
        ~ "switch (name.toLower) {\n" ~ generateCasesCode()
        ~ "default: throw new Exception(\"Unknown benchmark: \" ~ name);\n" ~ "}\n" ~ "}\n";
}
