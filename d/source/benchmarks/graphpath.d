module benchmarks.graphpath;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.container;
import std.range;
import std.random;
import std.typecons;
import benchmark;
import helper;

class GraphPathBenchmark : Benchmark {
protected:
    class Graph {
    public:
        int vertices;
        int components;
        int[][] adj;  

        this(int vertices, int components = 10) {
            this.vertices = vertices;
            this.components = components;
            adj = new int[][](vertices);
        }

        void addEdge(int u, int v) {
            adj[u] ~= v;
            adj[v] ~= u;
        }

        void generateRandom() {
            int componentSize = vertices / components;

            foreach (c; 0 .. components) {
                int startIdx = c * componentSize;
                int endIdx = (c == components - 1) ? vertices : (c + 1) * componentSize;

                foreach (i; startIdx + 1 .. endIdx) {
                    int parent = startIdx + Helper.nextInt(i - startIdx);
                    addEdge(i, parent);
                }

                int extraEdges = componentSize * 2;
                foreach (e; 0 .. extraEdges) {
                    int u = startIdx + Helper.nextInt(endIdx - startIdx);
                    int v = startIdx + Helper.nextInt(endIdx - startIdx);
                    if (u != v) addEdge(u, v);
                }
            }
        }

        bool sameComponent(int u, int v) {
            int componentSize = vertices / components;
            return (u / componentSize) == (v / componentSize);
        }
    }

    Graph graph;
    Tuple!(int, int)[] pairs;
    int nPairs;
    uint resultVal;

    Tuple!(int, int)[] generatePairs(int n) {
        auto result = new Tuple!(int, int)[n];
        int componentSize = graph.vertices / 10;

        foreach (i; 0 .. n) {
            if (Helper.nextInt(100) < 70) {
                int component = Helper.nextInt(10);
                int start = component * componentSize + Helper.nextInt(componentSize);
                int end;
                do {
                    end = component * componentSize + Helper.nextInt(componentSize);
                } while (end == start);
                result[i] = tuple(start, end);
            } else {
                int c1 = Helper.nextInt(10);
                int c2;
                do {
                    c2 = Helper.nextInt(10);
                } while (c2 == c1);
                int start = c1 * componentSize + Helper.nextInt(componentSize);
                int end = c2 * componentSize + Helper.nextInt(componentSize);
                result[i] = tuple(start, end);
            }
        }
        return result;
    }

    this() {
        resultVal = 0;
        nPairs = 0;
    }

protected:
    abstract long test();

public:
    override void prepare() {
        if (nPairs == 0) {
            nPairs = configVal("pairs");
            int vertices = configVal("vertices");
            int comps = max(10, vertices / 10_000);
            graph = new Graph(vertices, comps);
            graph.generateRandom();
            pairs = generatePairs(cast(int)nPairs);
        }
    }

    override void run(int iterationId) {
        resultVal += cast(uint)test();
    }

    override uint checksum() {
        return resultVal;
    }
}

class GraphPathBFS : GraphPathBenchmark {
private:
    int bfsShortestPath(int start, int target) {
        if (start == target) return 0;

        bool[] visited = new bool[graph.vertices];
        struct Node { int vertex; int distance; }
        Node[] queue = new Node[graph.vertices];
        int front = 0, back = 0;

        visited[start] = true;
        queue[back++] = Node(start, 0);

        while (front < back) {
            Node current = queue[front++];

            foreach (neighbor; graph.adj[current.vertex]) {
                if (neighbor == target) return current.distance + 1;

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue[back++] = Node(neighbor, current.distance + 1);
                }
            }
        }

        return -1;
    }

protected:
    override string className() const { return "GraphPathBFS"; }

public:
    override long test() {
        long totalLength = 0;

        foreach (pair; pairs) {
            totalLength += bfsShortestPath(pair[0], pair[1]);
        }

        return totalLength;
    }
}

class GraphPathDFS : GraphPathBenchmark {
private:
    int dfsFindPath(int start, int target) {
        if (start == target) return 0;

        bool[] visited = new bool[graph.vertices];
        struct Node { int vertex; int distance; }
        Node[] stack = new Node[graph.vertices];
        int top = 0;
        int bestPath = int.max;

        stack[top++] = Node(start, 0);

        while (top > 0) {
            Node current = stack[--top];

            if (visited[current.vertex] || current.distance >= bestPath) continue;
            visited[current.vertex] = true;

            foreach (neighbor; graph.adj[current.vertex]) {
                if (neighbor == target) {
                    if (current.distance + 1 < bestPath) {
                        bestPath = current.distance + 1;
                    }
                } else if (!visited[neighbor]) {
                    stack[top++] = Node(neighbor, current.distance + 1);
                }
            }
        }

        return (bestPath == int.max) ? -1 : bestPath;
    }

protected:
    override string className() const { return "GraphPathDFS"; }

public:
    override long test() {
        long totalLength = 0;

        foreach (pair; pairs) {
            totalLength += dfsFindPath(pair[0], pair[1]);
        }

        return totalLength;
    }
}

class GraphPathDijkstra : GraphPathBenchmark {
private:
    enum INF = int.max / 2;

    int dijkstraShortestPath(int start, int target) {
        if (start == target) return 0;

        int[] dist = new int[graph.vertices];
        bool[] visited = new bool[graph.vertices];

        dist[] = INF;
        dist[start] = 0;

        foreach (iteration; 0 .. graph.vertices) {
            int u = -1;
            int minDist = INF;

            foreach (v; 0 .. graph.vertices) {
                if (!visited[v] && dist[v] < minDist) {
                    minDist = dist[v];
                    u = v;
                }
            }

            if (u == -1 || minDist == INF || u == target) {
                return (u == target) ? minDist : -1;
            }

            visited[u] = true;

            foreach (v; graph.adj[u]) {
                if (dist[u] + 1 < dist[v]) {
                    dist[v] = dist[u] + 1;
                }
            }
        }

        return -1;
    }

protected:
    override string className() const { return "GraphPathDijkstra"; }

public:
    override long test() {
        long totalLength = 0;

        foreach (pair; pairs) {
            totalLength += dijkstraShortestPath(pair[0], pair[1]);
        }

        return totalLength;
    }
}