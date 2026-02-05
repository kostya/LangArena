package benchmarks

class GraphPathDFS : GraphPathBenchmark() {
    private fun dfsFindPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val stack = mutableListOf<Pair<Int, Int>>()
        var bestPath = Int.MAX_VALUE

        stack.add(Pair(start, 0))

        while (stack.isNotEmpty()) {
            val (v, dist) = stack.removeAt(stack.size - 1)

            if (visited[v] || dist >= bestPath) continue
            visited[v] = true

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) {
                    if (dist + 1 < bestPath) {
                        bestPath = dist + 1
                    }
                } else if (!visited[neighbor]) {
                    stack.add(Pair(neighbor, dist + 1))
                }
            }
        }

        return if (bestPath == Int.MAX_VALUE) -1 else bestPath
    }

    override fun test(): Long {
        var totalLength = 0L

        for ((start, end) in pairs) {
            val length = dfsFindPath(start, end)
            totalLength += length
        }

        return totalLength
    }

    override fun name(): String = "GraphPathDFS"
}