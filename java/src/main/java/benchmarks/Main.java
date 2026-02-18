package benchmarks;
import java.io.FileWriter;
import java.io.IOException;
import java.time.Instant;

public class Main {
    public static void main(String[] args) throws Exception {
        Benchmark.registerBenchmark("CLBG::Pidigits", () -> new Pidigits());
        Benchmark.registerBenchmark("Binarytrees::Obj", () -> new BinarytreesObj());
        Benchmark.registerBenchmark("Binarytrees::Arena", () -> new BinarytreesArena());
        Benchmark.registerBenchmark("Brainfuck::Array", () -> new BrainfuckArray());
        Benchmark.registerBenchmark("Brainfuck::Recursion", () -> new BrainfuckRecursion());
        Benchmark.registerBenchmark("CLBG::Fannkuchredux", () -> new Fannkuchredux());
        Benchmark.registerBenchmark("CLBG::Fasta", () -> new Fasta());
        Benchmark.registerBenchmark("CLBG::Knuckeotide", () -> new Knuckeotide());
        Benchmark.registerBenchmark("CLBG::Mandelbrot", () -> new Mandelbrot());
        Benchmark.registerBenchmark("Matmul::T1", () -> new Matmul1T());
        Benchmark.registerBenchmark("Matmul::T4", () -> new Matmul4T());
        Benchmark.registerBenchmark("Matmul::T8", () -> new Matmul8T());
        Benchmark.registerBenchmark("Matmul::T16", () -> new Matmul16T());
        Benchmark.registerBenchmark("CLBG::Nbody", () -> new Nbody());
        Benchmark.registerBenchmark("CLBG::RegexDna", () -> new RegexDna());
        Benchmark.registerBenchmark("CLBG::Revcomp", () -> new Revcomp());
        Benchmark.registerBenchmark("CLBG::Spectralnorm", () -> new Spectralnorm());
        Benchmark.registerBenchmark("Base64::Encode", () -> new Base64Encode());
        Benchmark.registerBenchmark("Base64::Decode", () -> new Base64Decode());
        Benchmark.registerBenchmark("Json::Generate", () -> new JsonGenerate());
        Benchmark.registerBenchmark("Json::ParseDom", () -> new JsonParseDom());
        Benchmark.registerBenchmark("Json::ParseMapping", () -> new JsonParseMapping());
        Benchmark.registerBenchmark("Etc::Primes", () -> new Primes());
        Benchmark.registerBenchmark("Etc::Noise", () -> new Noise());
        Benchmark.registerBenchmark("Etc::TextRaytracer", () -> new TextRaytracer());
        Benchmark.registerBenchmark("Etc::NeuralNet", () -> new NeuralNet());
        Benchmark.registerBenchmark("Sort::Quick", () -> new SortQuick());
        Benchmark.registerBenchmark("Sort::Merge", () -> new SortMerge());
        Benchmark.registerBenchmark("Sort::Self", () -> new SortSelf());
        Benchmark.registerBenchmark("Graph::BFS", () -> new GraphPathBFS());
        Benchmark.registerBenchmark("Graph::DFS", () -> new GraphPathDFS());
        Benchmark.registerBenchmark("Graph::AStar", () -> new GraphPathAStar());
        Benchmark.registerBenchmark("Hash::SHA256", () -> new BufferHashSHA256());
        Benchmark.registerBenchmark("Hash::CRC32", () -> new BufferHashCRC32());
        Benchmark.registerBenchmark("Etc::CacheSimulation", () -> new CacheSimulation());
        Benchmark.registerBenchmark("Calculator::Ast", () -> new CalculatorAst());
        Benchmark.registerBenchmark("Calculator::Interpreter", () -> new CalculatorInterpreter());
        Benchmark.registerBenchmark("Etc::GameOfLife", () -> new GameOfLife());
        Benchmark.registerBenchmark("Maze::Generator", () -> new MazeGenerator());
        Benchmark.registerBenchmark("Maze::BFS", () -> new MazeBFS());
        Benchmark.registerBenchmark("Maze::AStar", () -> new MazeAStar());
        Benchmark.registerBenchmark("Compress::BWTEncode", () -> new BWTEncode());
        Benchmark.registerBenchmark("Compress::BWTDecode", () -> new BWTDecode());
        Benchmark.registerBenchmark("Compress::HuffEncode", () -> new HuffEncode());
        Benchmark.registerBenchmark("Compress::HuffDecode", () -> new HuffDecode());
        Benchmark.registerBenchmark("Compress::ArithEncode", () -> new ArithEncode());
        Benchmark.registerBenchmark("Compress::ArithDecode", () -> new ArithDecode());
        Benchmark.registerBenchmark("Compress::LZWEncode", () -> new LZWEncode());
        Benchmark.registerBenchmark("Compress::LZWDecode", () -> new LZWDecode());

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