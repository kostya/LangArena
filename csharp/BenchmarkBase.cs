using System.Globalization;
using System.IO;
using System.Text.Json;

public abstract class Benchmark
{
    private double _timeDelta = 0.0;

    public abstract void Run(long IterationId);
    public abstract uint Checksum { get; }

    public virtual void Prepare() { }

    public long WarmupIterations
    {
        get
        {
            var className = GetType().Name;
            if (Helper.Config.RootElement.TryGetProperty(className, out var benchObj))
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
        var className = GetType().Name;
        return Helper.Config_i64(className, fieldName);
    }

    public long Iterations
    {
        get
        {
            var className = GetType().Name;
            return Helper.Config_i64(className, "iterations");
        }
    }

    public long ExpectedChecksum
    {
        get
        {
            var className = GetType().Name;
            return Helper.Config_i64(className, "checksum");
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

    private static List<BenchmarkInfo> GetBenchmarkFactories()
    {
        return new List<BenchmarkInfo>
        {
            CreateBenchmarkInfo<Pidigits>(),
            CreateBenchmarkInfo<Binarytrees>(),
            CreateBenchmarkInfo<BrainfuckArray>(),
            CreateBenchmarkInfo<BrainfuckRecursion>(),
            CreateBenchmarkInfo<Fannkuchredux>(),
            CreateBenchmarkInfo<Fasta>(),
            CreateBenchmarkInfo<Knuckeotide>(),
            CreateBenchmarkInfo<Mandelbrot>(),
            CreateBenchmarkInfo<Matmul1T>(),
            CreateBenchmarkInfo<Matmul4T>(),
            CreateBenchmarkInfo<Matmul8T>(),
            CreateBenchmarkInfo<Matmul16T>(),
            CreateBenchmarkInfo<Nbody>(),
            CreateBenchmarkInfo<RegexDna>(),
            CreateBenchmarkInfo<Revcomp>(),
            CreateBenchmarkInfo<Spectralnorm>(),
            CreateBenchmarkInfo<Base64Encode>(),
            CreateBenchmarkInfo<Base64Decode>(),
            CreateBenchmarkInfo<JsonGenerate>(),
            CreateBenchmarkInfo<JsonParseDom>(),
            CreateBenchmarkInfo<JsonParseMapping>(),
            CreateBenchmarkInfo<Primes>(),
            CreateBenchmarkInfo<Noise>(),
            CreateBenchmarkInfo<TextRaytracer>(),
            CreateBenchmarkInfo<NeuralNet>(),
            CreateBenchmarkInfo<SortQuick>(),
            CreateBenchmarkInfo<SortMerge>(),
            CreateBenchmarkInfo<SortSelf>(),
            CreateBenchmarkInfo<GraphPathBFS>(),
            CreateBenchmarkInfo<GraphPathDFS>(),
            CreateBenchmarkInfo<GraphPathAStar>(),
            CreateBenchmarkInfo<BufferHashSHA256>(),
            CreateBenchmarkInfo<BufferHashCRC32>(),
            CreateBenchmarkInfo<CacheSimulation>(),
            CreateBenchmarkInfo<CalculatorAst>(),
            CreateBenchmarkInfo<CalculatorInterpreter>(),
            CreateBenchmarkInfo<GameOfLife>(),
            CreateBenchmarkInfo<MazeGenerator>(),
            CreateBenchmarkInfo<AStarPathfinder>(),
            CreateBenchmarkInfo<BWTHuffEncode>(),
            CreateBenchmarkInfo<BWTHuffDecode>(),
        };
    }

    private static BenchmarkInfo CreateBenchmarkInfo<T>() where T : Benchmark, new()
    {
        return new BenchmarkInfo
        {
            Name = typeof(T).Name,
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