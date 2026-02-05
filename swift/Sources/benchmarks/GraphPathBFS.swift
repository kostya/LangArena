import Foundation

final class GraphPathBFS: GraphPathBenchmark {
    override init() {
        super.init()
    }

    override var name: String { return "GraphPathBFS" }

    private func bfsShortestPath(_ start: Int, _ target: Int) -> Int {
        if start == target { return 0 }
        var visited = [Bool](repeating: false, count: graph.vertices)
        var queue: [(Int, Int)] = []
        queue.reserveCapacity(graph.vertices)
        visited[start] = true
        queue.append((start, 0))
        var front = 0

        while front < queue.count {
            let (v, dist) = queue[front]
            front += 1

            for neighbor in graph.adj[v] {
                if neighbor == target { return dist + 1 }
                if !visited[neighbor] {
                    visited[neighbor] = true
                    queue.append((neighbor, dist + 1))
                }
            }
        }
        return -1
    }

    override func test() -> Int64 {
        var totalLength: Int64 = 0
        for (start, end) in pairs {
            let length = bfsShortestPath(start, end)
            totalLength += Int64(length)
        }
        return totalLength
    }
}