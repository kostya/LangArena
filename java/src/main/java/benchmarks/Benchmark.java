package benchmarks;

import java.io.FileWriter;
import java.util.*;
import java.util.Locale;

public abstract class Benchmark {
    public abstract void run();
    public abstract long getResult();
    
    public void prepare() {
        // optional override
    }
    
    public int getIterations() {
        String className = this.getClass().getSimpleName();
        String value = Helper.INPUT.get(className);
        return value != null ? Integer.parseInt(value) : 0;
    }
    
    private static final List<Supplier<Benchmark>> benchmarkFactories = new ArrayList<>();
    
    public static void registerBenchmark(Supplier<Benchmark> factory) {
        benchmarkFactories.add(factory);
    }
    
    public static void run(String singleBench) {
        Map<String, Double> results = new HashMap<>();
        double summaryTime = 0.0;
        int ok = 0, fails = 0;
        
        for (Supplier<Benchmark> factory : benchmarkFactories) {
            Benchmark bench = factory.get();
            String className = bench.getClass().getSimpleName();
            
            if ((singleBench == null || singleBench.equals(className)) && 
                !className.equals("SortBenchmark") && 
                !className.equals("BufferHashBenchmark") && 
                !className.equals("GraphPathBenchmark")) {
                
                System.out.print(className + ": ");
                
                Helper.reset();
                
                bench.prepare();
                
                long startTime = System.nanoTime();
                bench.run();
                double timeDelta = (System.nanoTime() - startTime) / 1_000_000_000.0;
                
                results.put(className, timeDelta);
                
                System.gc();
                try { Thread.sleep(0); } catch (InterruptedException e) {}
                System.gc();
                
                Long expected = Helper.EXPECT.get(className);
                if (bench.getResult() == (expected != null ? expected : 0)) {
                    System.out.print("OK ");
                    ok++;
                } else {
                    System.out.print("ERR[actual=" + bench.getResult() + 
                                   ", expected=" + expected + "] ");
                    fails++;
                }
                
                System.out.printf(Locale.US, "in %.3fs%n", timeDelta);
                summaryTime += timeDelta;
            }
        }
        
        // Write results to file
        try (FileWriter writer = new FileWriter("/tmp/results.js")) {
            writer.write("{");
            boolean first = true;
            for (Map.Entry<String, Double> entry : results.entrySet()) {
                if (!first) writer.write(", ");
                writer.write("\"" + entry.getKey() + "\": " + entry.getValue());
                first = false;
            }
            writer.write("}");
        } catch (Exception e) {
            System.err.println("Failed to write results: " + e.getMessage());
        }
        
        System.out.printf(Locale.US, "Summary: %.4fs, %d, %d, %d%n", summaryTime, ok + fails, ok, fails);
        
        if (fails > 0) {
            System.exit(1);
        }
    }
    
    @FunctionalInterface
    public interface Supplier<T> {
        T get();
    }
}