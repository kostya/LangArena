module benchmark_registry;

import std.functional;
import benchmark;

template registerAllBenchmarks(pairs...)
{
    static assert(pairs.length % 2 == 0, "Must be even number of arguments (key-value pairs)");

    static string generateMapEntries()
    {
        string result;
        static foreach (idx; 0 .. pairs.length)
        {
            static if (idx % 2 == 0)
            {
                result ~= "    \"" ~ pairs[idx] ~ "\": cast(Benchmark function()) (() => new "
                    ~ pairs[idx + 1].stringof ~ "()),\n";
            }
        }
        return result;
    }

    static string generateNameList()
    {
        string result = "static immutable string[] benchmarkNames = [\n";
        static foreach (idx; 0 .. pairs.length)
        {
            static if (idx % 2 == 0)
            {
                result ~= "    \"" ~ pairs[idx] ~ "\",\n";
            }
        }
        result ~= "];\n";
        return result;
    }

    enum registerAllBenchmarks = "alias BenchmarkFunc = Benchmark function();\n"
        ~ "static immutable BenchmarkFunc[string] benchmarkMap = [\n"
        ~ generateMapEntries() ~ "];\n" ~ "\n" ~ generateNameList() ~ "\n"
        ~ "string[] getAllBenchmarkNames() {\n" ~ "    return benchmarkNames.dup;\n" ~ "}\n" ~ "\n"
        ~ "Benchmark createBenchmark(string name) {\n"
        ~ "    auto p = name in benchmarkMap;\n"
        ~ "    if (p !is null) return (*p)();\n"
        ~ "    throw new Exception(\"Unknown benchmark: \" ~ name);\n" ~ "}\n";
}
