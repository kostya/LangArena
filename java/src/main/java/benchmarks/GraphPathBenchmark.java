package benchmarks;

import java.util.*;

public abstract class GraphPathBenchmark extends Benchmark {

    static class Graph {
        final int vertices;
        final int jumps;
        final int jumpLen;
        final List<List<Integer>> adj;

        Graph(int vertices, int jumps, int jumpLen) {
            this.vertices = vertices;
            this.jumps = jumps;
            this.jumpLen = jumpLen;
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

            for (int i = 1; i < vertices; i++) {
                addEdge(i, i - 1);
            }

            for (int v = 0; v < vertices; v++) {
                int numJumps = Helper.nextInt(jumps);
                for (int j = 0; j < numJumps; j++) {
                    int offset = Helper.nextInt(jumpLen) - jumpLen / 2;
                    int u = v + offset;

                    if (u >= 0 && u < vertices && u != v) {
                        addEdge(v, u);
                    }
                }
            }
        }
    }

    protected Graph graph;
    private long resultVal;

    public GraphPathBenchmark() {
        resultVal = 0L;
    }

    @Override
    public void prepare() {
        int vertices = (int) configVal("vertices");
        int jumps = (int) configVal("jumps");
        int jumpLen = (int) configVal("jump_len");

        graph = new Graph(vertices, jumps, jumpLen);
        graph.generateRandom();
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

class GraphPathBFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "GraphPathBFS";
    }

    @Override
    long test() {
        return bfsShortestPath(0, graph.vertices - 1);
    }

    private int bfsShortestPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Queue<int[]> queue = new ArrayDeque<>();

        visited[start] = true;
        queue.add(new int[] {start, 0});

        while (!queue.isEmpty()) {
            int[] current = queue.poll();
            int v = current[0];
            int dist = current[1];

            for (int neighbor : graph.adj.get(v)) {
                if (neighbor == target) return dist + 1;

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue.add(new int[] {neighbor, dist + 1});
                }
            }
        }

        return -1;
    }
}

class GraphPathDFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "GraphPathDFS";
    }

    @Override
    long test() {
        return dfsFindPath(0, graph.vertices - 1);
    }

    private int dfsFindPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Deque<int[]> stack = new ArrayDeque<>();
        int bestPath = Integer.MAX_VALUE;

        stack.push(new int[] {start, 0});

        while (!stack.isEmpty()) {
            int[] current = stack.pop();
            int v = current[0];
            int dist = current[1];

            if (visited[v] || dist >= bestPath) continue;
            visited[v] = true;

            for (int neighbor : graph.adj.get(v)) {
                if (neighbor == target) {
                    if (dist + 1 < bestPath) {
                        bestPath = dist + 1;
                    }
                } else if (!visited[neighbor]) {
                    stack.push(new int[] {neighbor, dist + 1});
                }
            }
        }

        return bestPath == Integer.MAX_VALUE ? -1 : bestPath;
    }
}

class PriorityQueueItem implements Comparable<PriorityQueueItem> {
    final int vertex;
    final int priority;

    PriorityQueueItem(int vertex, int priority) {
        this.vertex = vertex;
        this.priority = priority;
    }

    @Override
    public int compareTo(PriorityQueueItem other) {
        return Integer.compare(this.priority, other.priority);
    }
}

class GraphPathAStar extends GraphPathBenchmark {

    @Override
    public String name() {
        return "GraphPathAStar";
    }

    @Override
    long test() {
        return aStarShortestPath(0, graph.vertices - 1);
    }

    private int heuristic(int v, int target) {
        return target - v;
    }

    private int aStarShortestPath(int start, int target) {
        if (start == target) return 0;

        int[] gScore = new int[graph.vertices];
        int[] fScore = new int[graph.vertices];
        boolean[] closed = new boolean[graph.vertices];

        Arrays.fill(gScore, Integer.MAX_VALUE);
        Arrays.fill(fScore, Integer.MAX_VALUE);

        gScore[start] = 0;
        fScore[start] = heuristic(start, target);

        PriorityQueue<PriorityQueueItem> openSet = new PriorityQueue<>();
        boolean[] inOpenSet = new boolean[graph.vertices];

        openSet.add(new PriorityQueueItem(start, fScore[start]));
        inOpenSet[start] = true;

        while (!openSet.isEmpty()) {
            PriorityQueueItem current = openSet.poll();
            int currentVertex = current.vertex;
            inOpenSet[currentVertex] = false;

            if (currentVertex == target) {
                return gScore[currentVertex];
            }

            closed[currentVertex] = true;

            for (int neighbor : graph.adj.get(currentVertex)) {
                if (closed[neighbor]) continue;

                int tentativeG = gScore[currentVertex] + 1;

                if (tentativeG < gScore[neighbor]) {
                    gScore[neighbor] = tentativeG;
                    fScore[neighbor] = tentativeG + heuristic(neighbor, target);

                    if (!inOpenSet[neighbor]) {
                        openSet.add(new PriorityQueueItem(neighbor, fScore[neighbor]));
                        inOpenSet[neighbor] = true;
                    }
                }
            }
        }

        return -1;
    }
}