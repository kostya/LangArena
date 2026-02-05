package benchmarks

class GraphPathDijkstra : GraphPathBenchmark() {
    companion object {
        const val INF = Int.MAX_VALUE / 2
    }

    private fun dijkstraShortestPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val dist = IntArray(graph.vertices) { INF }
        val visited = BooleanArray(graph.vertices)

        dist[start] = 0

        for (iteration in 0 until graph.vertices) {

            var u = -1
            var minDist = INF

            for (v in 0 until graph.vertices) {
                if (!visited[v] && dist[v] < minDist) {
                    minDist = dist[v]
                    u = v
                }
            }

            if (u == -1 || minDist == INF || u == target) {
                return if (u == target) minDist else -1
            }

            visited[u] = true

            for (v in graph.adj[u]) {
                if (dist[u] + 1 < dist[v]) {
                    dist[v] = dist[u] + 1
                }
            }
        }

        return -1
    }

    override fun test(): Long {
        var totalLength = 0L

        for ((start, end) in pairs) {
            val length = dijkstraShortestPath(start, end)
            totalLength += length
        }

        return totalLength
    }

    override fun name(): String = "GraphPathDijkstra"
}