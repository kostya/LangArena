using System.Globalization;
using System.IO;
using System.Text.Json;

public abstract class Benchmark
{
    private double _timeDelta = 0.0;

    public abstract void Run(long IterationId);
    public abstract uint Checksum { get; }
    public abstract string TypeName { get; }

    public virtual void Prepare() { }

    public long WarmupIterations
    {
        get
        {
            if (Helper.Config.RootElement.TryGetProperty(TypeName, out var benchObj))
            {
                if (benchObj.TryGetProperty("warmup_iterations", out var warmupProp))
                {
                    return warmupProp.GetInt64();
                }
            }
            long iters = Iterations;
            return Math.Max((long)(iters * 0.2), 1);
        }
    }

    public virtual void Warmup()
    {
        long prepareIters = WarmupIterations;
        for (long i = 0; i < prepareIters; i++)
        {
            Run(i);
        }
    }

    public void RunAll()
    {
        long iters = Iterations;
        for (long i = 0; i < iters; i++)
        {
            Run(i);
        }
    }

    public long ConfigVal(string fieldName)
    {
        return Helper.Config_i64(TypeName, fieldName);
    }

    public long Iterations
    {
        get
        {
            return Helper.Config_i64(TypeName, "iterations");
        }
    }

    public long ExpectedChecksum
    {
        get
        {
            return Helper.Config_i64(TypeName, "checksum");
        }
    }

    public double TimeDelta
    {
        get => _timeDelta;
        set => _timeDelta = value;
    }

    private class BenchmarkInfo
    {
        public string Name { get; set; }
        public Func<Benchmark> Creator { get; set; }
    }

    private static BenchmarkInfo CreateBenchmarkInfo<T>(string name) where T : Benchmark, new()
    {
        return new BenchmarkInfo
        {
            Name = name,
            Creator = () => new T()
        };
    }

    private static List<BenchmarkInfo> GetBenchmarkFactories()
    {
        return new List<BenchmarkInfo>
        {

            CreateBenchmarkInfo<Pidigits>("CLBG::Pidigits"),
            CreateBenchmarkInfo<Fannkuchredux>("CLBG::Fannkuchredux"),
            CreateBenchmarkInfo<Fasta>("CLBG::Fasta"),
            CreateBenchmarkInfo<Knuckeotide>("CLBG::Knuckeotide"),
            CreateBenchmarkInfo<Mandelbrot>("CLBG::Mandelbrot"),
            CreateBenchmarkInfo<Nbody>("CLBG::Nbody"),
            CreateBenchmarkInfo<RegexDna>("CLBG::RegexDna"),
            CreateBenchmarkInfo<Revcomp>("CLBG::Revcomp"),
            CreateBenchmarkInfo<Spectralnorm>("CLBG::Spectralnorm"),

            CreateBenchmarkInfo<BinarytreesObj>("Binarytrees::Obj"),
            CreateBenchmarkInfo<BinarytreesArena>("Binarytrees::Arena"),

            CreateBenchmarkInfo<BrainfuckArray>("Brainfuck::Array"),
            CreateBenchmarkInfo<BrainfuckRecursion>("Brainfuck::Recursion"),

            CreateBenchmarkInfo<Matmul1T>("Matmul::Single"),
            CreateBenchmarkInfo<Matmul4T>("Matmul::T4"),
            CreateBenchmarkInfo<Matmul8T>("Matmul::T8"),
            CreateBenchmarkInfo<Matmul16T>("Matmul::T16"),

            CreateBenchmarkInfo<Base64Encode>("Base64::Encode"),
            CreateBenchmarkInfo<Base64Decode>("Base64::Decode"),

            CreateBenchmarkInfo<JsonGenerate>("Json::Generate"),
            CreateBenchmarkInfo<JsonParseDom>("Json::ParseDom"),
            CreateBenchmarkInfo<JsonParseMapping>("Json::ParseMapping"),

            CreateBenchmarkInfo<Sieve>("Etc::Sieve"),
            CreateBenchmarkInfo<TextRaytracer>("Etc::TextRaytracer"),
            CreateBenchmarkInfo<NeuralNet>("Etc::NeuralNet"),
            CreateBenchmarkInfo<CacheSimulation>("Etc::CacheSimulation"),
            CreateBenchmarkInfo<GameOfLife>("Etc::GameOfLife"),

            CreateBenchmarkInfo<SortQuick>("Sort::Quick"),
            CreateBenchmarkInfo<SortMerge>("Sort::Merge"),
            CreateBenchmarkInfo<SortSelf>("Sort::Self"),

            CreateBenchmarkInfo<GraphPathBFS>("Graph::BFS"),
            CreateBenchmarkInfo<GraphPathDFS>("Graph::DFS"),
            CreateBenchmarkInfo<GraphPathAStar>("Graph::AStar"),

            CreateBenchmarkInfo<BufferHashSHA256>("Hash::SHA256"),
            CreateBenchmarkInfo<BufferHashCRC32>("Hash::CRC32"),

            CreateBenchmarkInfo<CalculatorAst>("Calculator::Ast"),
            CreateBenchmarkInfo<CalculatorInterpreter>("Calculator::Interpreter"),

            CreateBenchmarkInfo<MazeGenerator>("Maze::Generator"),
            CreateBenchmarkInfo<MazeBFS>("Maze::BFS"),
            CreateBenchmarkInfo<MazeAStar>("Maze::AStar"),

            CreateBenchmarkInfo<BWTEncode>("Compress::BWTEncode"),
            CreateBenchmarkInfo<BWTDecode>("Compress::BWTDecode"),
            CreateBenchmarkInfo<HuffEncode>("Compress::HuffEncode"),
            CreateBenchmarkInfo<HuffDecode>("Compress::HuffDecode"),
            CreateBenchmarkInfo<ArithEncode>("Compress::ArithEncode"),
            CreateBenchmarkInfo<ArithDecode>("Compress::ArithDecode"),
            CreateBenchmarkInfo<LZWEncode>("Compress::LZWEncode"),
            CreateBenchmarkInfo<LZWDecode>("Compress::LZWDecode"),

            CreateBenchmarkInfo<Jaro>("Distance::Jaro"),
            CreateBenchmarkInfo<NGram>("Distance::NGram"),

            CreateBenchmarkInfo<Words>("Etc::Words"),
            CreateBenchmarkInfo<Words>("Etc::LogParser"),
        };
    }

    private static BenchmarkInfo CreateBenchmarkInfo<T>() where T : Benchmark, new()
    {
        var type = typeof(T);
        var name = type.Name;

        var namespace_name = type.Namespace;

        if (!string.IsNullOrEmpty(namespace_name))
        {
            name = $"{namespace_name}::{name}";
        }

        else if (type.DeclaringType != null)
        {
            name = $"{type.DeclaringType.Name}::{name}";
        }

        return new BenchmarkInfo
        {
            Name = name,
            Creator = () => new T()
        };
    }

    public static void All(string? singleBench = null)
    {
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        Console.WriteLine($"start: {now}");

        var results = new Dictionary<string, double>();
        double summaryTime = 0.0;
        int ok = 0, fails = 0;

        var benchmarkFactories = GetBenchmarkFactories();

        foreach (var factory in benchmarkFactories)
        {
            var className = factory.Name;

            if (!string.IsNullOrEmpty(singleBench) &&
                !className.ToLower().Contains(singleBench.ToLower()))
                continue;

            if (className == "SortBenchmark" ||
                className == "BufferHashBenchmark" ||
                className == "GraphPathBenchmark")
                continue;

            if (!Helper.Config.RootElement.TryGetProperty(className, out _))
            {
                Console.WriteLine($"Skipping {className} - no config in test.js");
                continue;
            }

            Console.Write($"{className}: ");

            Helper.Reset();

            try
            {

                var benchmark = factory.Creator();

                benchmark.Prepare();
                benchmark.Warmup();
                GC.Collect();
                Helper.Reset();

                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                benchmark.RunAll();
                stopwatch.Stop();

                var timeDelta = stopwatch.Elapsed.TotalSeconds;
                benchmark.TimeDelta = timeDelta;
                results[className] = timeDelta;

                GC.Collect();
                Thread.Sleep(0);
                GC.Collect();

                var actual = benchmark.Checksum;
                var expected = benchmark.ExpectedChecksum;

                if (actual == expected)
                {
                    Console.Write("OK ");
                    ok++;
                }
                else
                {
                    Console.Write($"ERR[actual={actual}, expected={expected}] ");
                    fails++;
                }

                Console.WriteLine($"in {timeDelta:F3}s");
                summaryTime += timeDelta;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ERROR: {ex.Message}");
                fails++;
            }
        }

        try
        {
            var json = "{" + string.Join(",", results.Select(kv => $"\"{kv.Key}\":{kv.Value}")) + "}";
            File.WriteAllText("/tmp/results.js", json);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error saving results: {ex.Message}");
        }

        Console.WriteLine(
            string.Format(CultureInfo.InvariantCulture,
            "Summary: {0:F4}s, {1}, {2}, {3}",
            summaryTime, ok + fails, ok, fails));

        File.WriteAllText("/tmp/recompile_marker", "RECOMPILE_MARKER_0");

        if (fails > 0 || ok == 0)
        {
            Environment.Exit(1);
        }
    }
}