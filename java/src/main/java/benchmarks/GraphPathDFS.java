package benchmarks;

import java.util.*;

public class GraphPathDFS extends GraphPathBenchmark {

    @Override
    public String name() {
        return "GraphPathDFS";
    }

    @Override
    long test() {
        long totalLength = 0L;

        for (int[] pair : pairs) {
            int length = dfsFindPath(pair[0], pair[1]);
            totalLength += length;
        }

        return totalLength;
    }

    private int dfsFindPath(int start, int target) {
        if (start == target) return 0;

        boolean[] visited = new boolean[graph.vertices];
        Deque<int[]> stack = new ArrayDeque<>();
        int bestPath = Integer.MAX_VALUE;

        stack.push(new int[]{start, 0});

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
                    stack.push(new int[]{neighbor, dist + 1});
                }
            }
        }

        return bestPath == Integer.MAX_VALUE ? -1 : bestPath;
    }
}