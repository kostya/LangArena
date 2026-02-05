package benchmarks;

import java.util.*;

public class GraphPathBFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "GraphPathBFS";
    }

    @Override
    long test() {
        long totalLength = 0L;

        for (int[] pair : pairs) {
            int length = bfsShortestPath(pair[0], pair[1]);
            totalLength += length;
        }

        return totalLength;
    }

    private int bfsShortestPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Queue<int[]> queue = new ArrayDeque<>(); 

        visited[start] = true;
        queue.add(new int[]{start, 0});

        while (!queue.isEmpty()) {
            int[] current = queue.poll();
            int v = current[0];
            int dist = current[1];

            for (int neighbor : graph.adj.get(v)) {
                if (neighbor == target) return dist + 1;

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue.add(new int[]{neighbor, dist + 1});
                }
            }
        }

        return -1; 
    }
}