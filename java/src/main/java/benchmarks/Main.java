package benchmarks;
import java.io.FileWriter;
import java.io.IOException;
import java.time.Instant;

public class Main {
    public static void main(String[] args) throws Exception {
        Benchmark.registerBenchmark(() -> new Pidigits());
        Benchmark.registerBenchmark(() -> new BinarytreesObj());
        Benchmark.registerBenchmark(() -> new BinarytreesArena());
        Benchmark.registerBenchmark(() -> new BrainfuckArray());
        Benchmark.registerBenchmark(() -> new BrainfuckRecursion());
        Benchmark.registerBenchmark(() -> new Fannkuchredux());
        Benchmark.registerBenchmark(() -> new Fasta());
        Benchmark.registerBenchmark(() -> new Knuckeotide());
        Benchmark.registerBenchmark(() -> new Mandelbrot());
        Benchmark.registerBenchmark(() -> new Matmul1T());
        Benchmark.registerBenchmark(() -> new Matmul4T());
        Benchmark.registerBenchmark(() -> new Matmul8T());
        Benchmark.registerBenchmark(() -> new Matmul16T());
        Benchmark.registerBenchmark(() -> new Nbody());
        Benchmark.registerBenchmark(() -> new RegexDna());
        Benchmark.registerBenchmark(() -> new Revcomp());
        Benchmark.registerBenchmark(() -> new Spectralnorm());
        Benchmark.registerBenchmark(() -> new Base64Encode());
        Benchmark.registerBenchmark(() -> new Base64Decode());
        Benchmark.registerBenchmark(() -> new JsonGenerate());
        Benchmark.registerBenchmark(() -> new JsonParseDom());
        Benchmark.registerBenchmark(() -> new JsonParseMapping());
        Benchmark.registerBenchmark(() -> new Primes());
        Benchmark.registerBenchmark(() -> new Noise());
        Benchmark.registerBenchmark(() -> new TextRaytracer());
        Benchmark.registerBenchmark(() -> new NeuralNet());
        Benchmark.registerBenchmark(() -> new SortQuick());
        Benchmark.registerBenchmark(() -> new SortMerge());
        Benchmark.registerBenchmark(() -> new SortSelf());
        Benchmark.registerBenchmark(() -> new GraphPathBFS());
        Benchmark.registerBenchmark(() -> new GraphPathDFS());
        Benchmark.registerBenchmark(() -> new GraphPathAStar());
        Benchmark.registerBenchmark(() -> new BufferHashSHA256());
        Benchmark.registerBenchmark(() -> new BufferHashCRC32());
        Benchmark.registerBenchmark(() -> new CacheSimulation());
        Benchmark.registerBenchmark(() -> new CalculatorAst());
        Benchmark.registerBenchmark(() -> new CalculatorInterpreter());
        Benchmark.registerBenchmark(() -> new GameOfLife());
        Benchmark.registerBenchmark(() -> new MazeGenerator());
        Benchmark.registerBenchmark(() -> new AStarPathfinder());
        Benchmark.registerBenchmark(() -> new BWTHuffEncode());
        Benchmark.registerBenchmark(() -> new BWTHuffDecode());

        long now = Instant.now().toEpochMilli();
        System.out.println("start: " + now);

        String configFile = null;
        String singleBench = null;

        for (String arg : args) {
            if (arg.endsWith(".js")) {
                configFile = arg;
            } else {
                singleBench = arg;
            }
        }

        try {
            Helper.loadConfig(configFile);

            if (Helper.CONFIG.length() == 0) {
                System.err.println("Warning: No test cases loaded from config file");
                System.err.println("Usage: mvn exec:java -Dexec.args=\"test.js BrainfuckRecursion\"");
                System.err.println("Or: mvn exec:java -Dexec.args=\"../run.js\"");
                System.exit(1);
            }
        } catch (Exception e) {
            System.err.println("Error loading config file '" +
                               (configFile != null ? configFile : "test.js") +
                               "': " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }

        try (FileWriter writer = new FileWriter("/tmp/recompile_marker")) {
            writer.write("RECOMPILE_MARKER_0");
        }

        Benchmark.all(singleBench);
        System.exit(0);
    }
}