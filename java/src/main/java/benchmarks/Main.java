package benchmarks;
import java.io.FileWriter;
import java.io.IOException;

public class Main {
    public static void main(String[] args) throws Exception {
        Benchmark.registerBenchmark(() -> new Pidigits());
        Benchmark.registerBenchmark(() -> new Binarytrees());
        Benchmark.registerBenchmark(() -> new BrainfuckHashMap());
        Benchmark.registerBenchmark(() -> new BrainfuckRecursion());   
        Benchmark.registerBenchmark(() -> new Fannkuchredux());             
        Benchmark.registerBenchmark(() -> new Fasta());
        Benchmark.registerBenchmark(() -> new Knuckeotide());
        Benchmark.registerBenchmark(() -> new Mandelbrot());        
        Benchmark.registerBenchmark(() -> new Matmul());
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
        Benchmark.registerBenchmark(() -> new GraphPathDijkstra());
        Benchmark.registerBenchmark(() -> new BufferHashSHA256());
        Benchmark.registerBenchmark(() -> new BufferHashCRC32());
        Benchmark.registerBenchmark(() -> new CacheSimulation());
        Benchmark.registerBenchmark(() -> new CalculatorAst());
        Benchmark.registerBenchmark(() -> new CalculatorInterpreter());                                               
        Benchmark.registerBenchmark(() -> new GameOfLife());
        Benchmark.registerBenchmark(() -> new MazeGenerator());
        Benchmark.registerBenchmark(() -> new AStarPathfinder());
        Benchmark.registerBenchmark(() -> new Compression());

        // Обработка аргументов
        String configFile = null;
        String singleBench = null;
        
        for (String arg : args) {
            if (arg.endsWith(".txt")) {
                configFile = arg;
            } else {
                singleBench = arg;
            }
        }
        
        try {
            Helper.loadConfig(configFile);
            
            if (Helper.INPUT.isEmpty()) {
                System.err.println("Warning: No test cases loaded from config file");
                System.err.println("Usage: mvn exec:java -Dexec.args=\"test.txt BrainfuckRecursion\"");
                System.err.println("Or: mvn exec:java -Dexec.args=\"../run.txt\"");
                System.exit(1);
            }
        } catch (Exception e) {
            System.err.println("Error loading config file '" + 
                             (configFile != null ? configFile : "test.txt") + 
                             "': " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }

        try (FileWriter writer = new FileWriter("/tmp/recompile_marker")) {
            writer.write("RECOMPILE_MARKER_0");
        }
        
        Benchmark.run(singleBench);
    }
}