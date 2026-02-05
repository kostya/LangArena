package benchmarks;

import java.io.FileWriter;
import java.util.*;
import java.util.Locale;

public abstract class Benchmark {
    protected double timeDelta = 0.0;

    public abstract void run(int iterationId);
    public abstract long checksum();

    public void prepare() {

    }

    public String name() {
        return this.getClass().getSimpleName();
    }

    public long warmupIterations() {
        if (Helper.CONFIG.has(name()) && Helper.CONFIG.getJSONObject(name()).has("warmup_iterations")) {
            return Helper.CONFIG.getJSONObject(name()).getLong("warmup_iterations");
        } else {
            long iters = iterations();
            return Math.max((long)(iters * 0.2), 1L);
        }
    }

    public void warmup() {
        long prepareIters = warmupIterations();
        for (long i = 0; i < prepareIters; i++) {
            this.run((int)i);
        }
    }

    public void runAll() {
        long iters = iterations();
        for (long i = 0; i < iters; i++) {
            this.run((int)i);
        }
    }

    public long configVal(String fieldName) {
        return Helper.configI64(this.name(), fieldName);
    }

    public long iterations() {
        return configVal("iterations");
    }

    public long expectedChecksum() {
        return configVal("checksum");
    }

    public void setTimeDelta(double delta) {
        timeDelta = delta;
    }

    private static final List<Supplier<Benchmark>> benchmarkFactories = new ArrayList<>();

    public static void registerBenchmark(Supplier<Benchmark> factory) {
        benchmarkFactories.add(factory);
    }

    private static String toLower(String str) {
        return str.toLowerCase(Locale.US);
    }

    public static void all(String singleBench) {
        Map<String, Double> results = new HashMap<>();
        double summaryTime = 0.0;
        int ok = 0, fails = 0;

        for (Supplier<Benchmark> factory : benchmarkFactories) {
            Benchmark bench = factory.get();
            String className = bench.name();

            if (singleBench != null && !singleBench.isEmpty() && 
                !toLower(className).contains(toLower(singleBench))) {
                continue;
            }

            System.out.print(className + ": ");

            Helper.reset();

            bench.prepare();
            bench.warmup();

            Helper.reset();

            long startTime = System.nanoTime();
            bench.runAll();
            double timeDelta = (System.nanoTime() - startTime) / 1_000_000_000.0;

            bench.setTimeDelta(timeDelta);
            results.put(className, timeDelta);

            System.gc();
            try { Thread.sleep(0); } catch (InterruptedException e) {}
            System.gc();

            long check = bench.checksum() & 0xFFFFFFFFL;
            long expected = bench.expectedChecksum();
            if (check == expected) {
                System.out.print("OK ");
                ok++;
            } else {
                System.out.print("ERR[actual=" + check + 
                               ", expected=" + expected + "] ");
                fails++;
            }

            System.out.printf(Locale.US, "in %.3fs%n", timeDelta);
            summaryTime += timeDelta;
        }

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