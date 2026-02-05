final class GraphPathDFS: GraphPathBenchmark {
    override init() {
        super.init()
    }

    override var name: String { return "GraphPathDFS" }

    private func dfsFindPath(_ start: Int, _ target: Int) -> Int {
        if start == target { return 0 }

        var visited = [Bool](repeating: false, count: graph.vertices)
        var stack: [(Int, Int)] = [(start, 0)]
        var bestPath = Int.max

        while !stack.isEmpty {
            let (v, dist) = stack.removeLast()

            if visited[v] || dist >= bestPath {
                continue
            }

            visited[v] = true

            for neighbor in graph.adj[v] {
                if neighbor == target {
                    if dist + 1 < bestPath {
                        bestPath = dist + 1
                    }
                } else if !visited[neighbor] {
                    stack.append((neighbor, dist + 1))
                }
            }
        }

        return bestPath == Int.max ? -1 : bestPath
    }

    override func test() -> Int64 {
        var totalLength: Int64 = 0
        for (start, end) in pairs {
            let length = dfsFindPath(start, end)
            totalLength += Int64(length)
        }
        return totalLength
    }
}