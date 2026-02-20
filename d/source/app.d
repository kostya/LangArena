module app;

import std.stdio;
import std.datetime : Clock, MonoTime, Duration;
import std.conv;
import std.string;
import std.algorithm;
import std.file;
import std.json;
import core.thread : Thread;
import core.stdc.stdlib : exit;

import benchmark;
import benchmark_registry;
import helper;

import benchmarks.pidigits;
import benchmarks.binarytrees;
import benchmarks.brainfuckarray;
import benchmarks.brainfuckrecursion;
import benchmarks.fannkuchredux;
import benchmarks.fasta;
import benchmarks.knuckeotide;
import benchmarks.regexdna;
import benchmarks.revcomp;
import benchmarks.mandelbrot;
import benchmarks.matmul1t;
import benchmarks.matmul4t;
import benchmarks.nbody;
import benchmarks.spectralnorm;
import benchmarks.base64encode;
import benchmarks.base64decode;
import benchmarks.primes;
import benchmarks.noise;
import benchmarks.textraytracer;
import benchmarks.neuralnet;
import benchmarks.sort;
import benchmarks.graphpath;
import benchmarks.bufferhash;
import benchmarks.cachesimulation;
import benchmarks.calculatorast;
import benchmarks.calculatorinterpreter;
import benchmarks.gameoflife;
import benchmarks.mazegenerator;
import benchmarks.astarpathfinder;
import benchmarks.compress;
import benchmarks.jsonbench;

mixin(registerAllBenchmarks!("Pidigits", Pidigits, "BinarytreesObj",
        BinarytreesObj, "BinarytreesArena", BinarytreesArena, "BrainfuckArray",
        BrainfuckArray, "BrainfuckRecursion", BrainfuckRecursion,
        "Fannkuchredux", Fannkuchredux, "Fasta", Fasta, "Knuckeotide",
        Knuckeotide, "Mandelbrot", Mandelbrot, "Matmul1T", Matmul1T, "Matmul4T", Matmul4T, "Matmul8T", Matmul8T,
        "Matmul16T", Matmul16T, "Nbody", Nbody, "RegexDna", RegexDna,
        "Revcomp", Revcomp, "Spectralnorm", Spectralnorm, "Base64Encode",
        Base64Encode, "Base64Decode", Base64Decode, "JsonGenerate",
        JsonGenerate, "JsonParseDom", JsonParseDom, "JsonParseMapping",
        JsonParseMapping, "Primes", Primes, "Noise", Noise, "TextRaytracer",
        TextRaytracer, "NeuralNet", NeuralNet, "SortQuick",
        SortQuick, "SortMerge", SortMerge, "SortSelf", SortSelf, "GraphPathBFS",
        GraphPathBFS, "GraphPathDFS", GraphPathDFS, "GraphPathAStar",
        GraphPathAStar, "BufferHashSHA256", BufferHashSHA256,
        "BufferHashCRC32", BufferHashCRC32, "CacheSimulation", CacheSimulation,
        "CalculatorAst", CalculatorAst, "CalculatorInterpreter",
        CalculatorInterpreter, "GameOfLife",
        GameOfLife, "MazeGenerator", MazeGenerator, "AStarPathfinder",
        AStarPathfinder, "Compress::BWTEncode", BWTEncode, "Compress::BWTDecode", BWTDecode,
        "Compress::HuffEncode", HuffEncode, "Compress::HuffDecode", HuffDecode,
        "Compress::ArithEncode",
        ArithEncode, "Compress::ArithDecode", ArithDecode,
        "Compress::LZWEncode", LZWEncode, "Compress::LZWDecode", LZWDecode));

void benchmarkAll(string singleBench = "")
{

    auto benchmarks = getAllBenchmarkNames();

    double[string] results;
    double summaryTime = 0.0;
    int ok = 0;
    int fails = 0;

    foreach (benchName; benchmarks)
    {
        if (!singleBench.empty && benchName.toLower.indexOf(singleBench.toLower) == -1)
        {
            continue;
        }

        Benchmark bench = createBenchmark(benchName);
        std.stdio.write(bench.name(), ": ");
        stdout.flush();

        Helper.reset();
        bench.prepare();

        bench.warmup();
        Helper.reset();

        auto start = MonoTime.currTime;
        bench.runAll();
        auto end = MonoTime.currTime;
        auto duration = (end - start).total!"msecs" / 1000.0;

        bench.setTimeDelta(duration);
        results[bench.name()] = duration;

        if (bench.checksum == bench.expectedChecksum)
        {
            std.stdio.write("OK ");
            ok++;
        }
        else
        {
            std.stdio.write("ERR[actual=", bench.checksum, ", expected=",
                    bench.expectedChecksum, "] ");
            fails++;
        }

        std.stdio.writefln("in %.3fs", duration);

        summaryTime += duration;
        bench = null;
    }

    auto resultsFile = File("/tmp/results.js", "w");
    resultsFile.write("{");
    bool first = true;
    foreach (name, time; results)
    {
        if (!first)
            resultsFile.write(",");
        resultsFile.writef(`"%s":%s`, name, time);
        first = false;
    }
    resultsFile.write("}");
    resultsFile.close();

    if (ok + fails > 0)
    {
        std.stdio.writefln("Summary: %.4fs, %s, %s, %s", summaryTime, ok + fails, ok, fails);
    }

    if (fails > 0)
    {
        exit(1);
    }
}

void main(string[] args)
{
    import std.datetime : Clock;
    import std.datetime.systime : SysTime;

    auto now = Clock.currTime();

    auto unixSeconds = now.toUnixTime();

    long unixMs = unixSeconds * 1000L;

    writeln("start: ", unixMs);

    if (args.length > 1)
    {
        loadConfig(args[1]);
    }
    else
    {
        loadConfig();
    }

    if (args.length > 2)
    {
        benchmarkAll(args[2]);
    }
    else
    {
        benchmarkAll();
    }

    auto marker = File("/tmp/recompile_marker", "w");
    marker.write("RECOMPILE_MARKER_0");
    marker.close();
}
