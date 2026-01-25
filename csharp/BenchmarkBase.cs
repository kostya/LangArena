using System.Globalization;
using System.IO;

public abstract class Benchmark
{
    public abstract void Run();
    public abstract long Result { get; }
    
    public virtual void Prepare() { }
    
    public int Iterations 
    {
        get
        {
            var className = GetType().Name;
            if (Helper.Input.TryGetValue(className, out var value))
            {
                if (int.TryParse(value, out var iter))
                {
                    return iter;
                }
            }
            Console.WriteLine($"Warning: No iterations config for {className}, using default 1");
            return 1;
        }
    }
    
    public static void RunBenchmarks(string? singleBench = null)
    {
        // Console.WriteLine("\n=== Starting benchmarks ===");
        
        var results = new Dictionary<string, double>();
        double summaryTime = 0.0;
        int ok = 0, fails = 0;
        
        // ЯВНЫЙ СПИСОК БЕНЧМАРКОВ (для работы с AOT)
        var benchmarks = new List<Benchmark>
        {
            new Pidigits(),
            new Binarytrees(),
            new BrainfuckHashMap(),         
            new BrainfuckRecursion(),                                   
            new Fannkuchredux(),
            new Fasta(),
            new Knuckeotide(),
            new Mandelbrot(),
            new Matmul(),
            new Matmul4T(),
            new Matmul8T(),
            new Matmul16T(),
            new Nbody(),
            new RegexDna(),
            new Revcomp(),
            new Spectralnorm(),
            new Base64Encode(),
            new Base64Decode(),            
            new JsonGenerate(),
            new JsonParseDom(),
            new JsonParseMapping(),
            new Primes(),
            new Noise(),
            new TextRaytracer(),
            new NeuralNet(),
            new SortQuick(),
            new SortMerge(),
            new SortSelf(),
            new GraphPathBFS(),
            new GraphPathDFS(),
            new GraphPathDijkstra(),
            new BufferHashSHA256(),
            new BufferHashCRC32(),
            new CacheSimulation(),
            new CalculatorAst(),
            new CalculatorInterpreter(),           
            new GameOfLife(),
            new MazeGenerator(),
            new AStarPathfinder(),           
            new Compression(),           
        };
        
        foreach (var benchmark in benchmarks)
        {
            var className = benchmark.GetType().Name;
            
            // Пропускаем, если запускаем только конкретный бенчмарк
            if (!string.IsNullOrEmpty(singleBench) && className != singleBench)
                continue;
            
            // Пропускаем исключенные типы
            if (className == "SortBenchmark" || 
                className == "BufferHashBenchmark" || 
                className == "GraphPathBenchmark")
                continue;
            
            // Проверяем, есть ли конфиг для этого бенчмарка
            if (!Helper.Input.ContainsKey(className))
            {
                Console.WriteLine($"Skipping {className} - no config in test.txt");
                continue;
            }
            
            Console.Write($"{className}: ");
            
            Helper.Reset();
            
            try
            {
                benchmark.Prepare();
                
                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                benchmark.Run();
                stopwatch.Stop();
                
                var timeDelta = stopwatch.Elapsed.TotalSeconds;
                results[className] = timeDelta;
                
                GC.Collect();
                Thread.Sleep(0);
                GC.Collect();
                
                var actual = benchmark.Result;
                var expected = Helper.Expect.GetValueOrDefault(className, 0);
                
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
        
        // Сохраняем результаты
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
            // Console.WriteLine("\n❌ Benchmark run failed!");
            Environment.Exit(1);
        }
    }
}