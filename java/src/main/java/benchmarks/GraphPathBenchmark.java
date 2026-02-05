package benchmarks;

import java.util.*;

public abstract class GraphPathBenchmark extends Benchmark {

    static class Graph {
        final int vertices;
        final List<List<Integer>> adj;
        final int componentsCount;

        Graph(int vertices, int components) {
            this.vertices = vertices;
            this.componentsCount = components;
            this.adj = new ArrayList<>(vertices);

            for (int i = 0; i < vertices; i++) {
                adj.add(new ArrayList<>());
            }
        }

        void addEdge(int u, int v) {
            adj.get(u).add(v);
            adj.get(v).add(u);
        }

        void generateRandom() {
            int componentSize = vertices / componentsCount;

            for (int c = 0; c < componentsCount; c++) {
                int startIdx = c * componentSize;
                int endIdx = (c + 1) * componentSize;
                if (c == componentsCount - 1) {
                    endIdx = vertices;
                }

                for (int i = startIdx + 1; i < endIdx; i++) {
                    int parent = startIdx + Helper.nextInt(i - startIdx);
                    addEdge(i, parent);
                }

                for (int i = 0; i < componentSize * 2; i++) {
                    int u = startIdx + Helper.nextInt(endIdx - startIdx);
                    int v = startIdx + Helper.nextInt(endIdx - startIdx);
                    if (u != v) {
                        addEdge(u, v);
                    }
                }
            }
        }
    }

    protected Graph graph;
    protected List<int[]> pairs;
    private long resultVal;
    private long nPairs;

    public GraphPathBenchmark() {
        resultVal = 0L;
        nPairs = 0L;
    }

    @Override
    public void prepare() {
        if (nPairs == 0) {
            nPairs = configVal("pairs");
            int vertices = (int) configVal("vertices");
            int components = Math.max(10, vertices / 10_000);
            graph = new Graph(vertices, components);
            graph.generateRandom();
            pairs = generatePairs((int) nPairs);
        }
    }

    private List<int[]> generatePairs(int n) {
        List<int[]> pairs = new ArrayList<>(n);
        int componentSize = graph.vertices / 10;

        for (int i = 0; i < n; i++) {

            if (Helper.nextInt(100) < 70) {

                int component = Helper.nextInt(10);
                int start = component * componentSize + Helper.nextInt(componentSize);
                int end;
                do {
                    end = component * componentSize + Helper.nextInt(componentSize);
                } while (end == start);
                pairs.add(new int[]{start, end});
            } else {

                int c1 = Helper.nextInt(10);
                int c2;
                do {
                    c2 = Helper.nextInt(10);
                } while (c2 == c1);

                int start = c1 * componentSize + Helper.nextInt(componentSize);
                int end = c2 * componentSize + Helper.nextInt(componentSize);
                pairs.add(new int[]{start, end});
            }
        }

        return pairs;
    }

    abstract long test();

    @Override
    public void run(int iterationId) {
        resultVal += test();
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}