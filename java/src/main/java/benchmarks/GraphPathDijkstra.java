package benchmarks;

import java.util.*;

public class GraphPathDijkstra extends GraphPathBenchmark {
    private static final int INF = Integer.MAX_VALUE / 2;

    @Override
    public String name() {
        return "GraphPathDijkstra";
    }

    @Override
    long test() {
        long totalLength = 0L;

        for (int[] pair : pairs) {
            int length = dijkstraShortestPath(pair[0], pair[1]);
            totalLength += length;
        }

        return totalLength;
    }

    private int dijkstraShortestPath(int start, int target) {
        if (start == target) return 0;

        int[] dist = new int[graph.vertices];
        boolean[] visited = new boolean[graph.vertices];

        Arrays.fill(dist, INF);
        dist[start] = 0;

        for (int iteration = 0; iteration < graph.vertices; iteration++) {

            int u = -1;
            int minDist = INF;

            for (int v = 0; v < graph.vertices; v++) {
                if (!visited[v] && dist[v] < minDist) {
                    minDist = dist[v];
                    u = v;
                }
            }

            if (u == -1 || minDist == INF || u == target) {
                return (u == target) ? minDist : -1;
            }

            visited[u] = true;

            for (int v : graph.adj.get(u)) {
                if (dist[u] + 1 < dist[v]) {
                    dist[v] = dist[u] + 1;
                }
            }
        }

        return -1;
    }
}