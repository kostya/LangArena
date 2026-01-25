package benchmarks

import java.util.ArrayDeque

class GraphPathBFS : GraphPathBenchmark() {
    override fun test(): Long {
        var totalLength = 0L

        for ((start, end) in pairs) {
            val length = bfsShortestPath(start, end)
            totalLength += length
        }

        return totalLength
    }

    private fun bfsShortestPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val queue = ArrayDeque<Pair<Int, Int>>() // vertex, distance

        visited[start] = true
        queue.add(Pair(start, 0))

        while (queue.isNotEmpty()) {
            val (v, dist) = queue.removeFirst()

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) return dist + 1
                
                if (!visited[neighbor]) {
                    visited[neighbor] = true
                    queue.add(Pair(neighbor, dist + 1))
                }
            }
        }

        return -1 // путь не найден
    }
}