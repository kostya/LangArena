import Foundation

final class GraphPathDijkstra: GraphPathBenchmark {
    private static let INF = Int.max / 2

    override init() {
        super.init()
    }

    override var name: String { return "GraphPathDijkstra" }

    private func dijkstraShortestPath(_ start: Int, _ target: Int) -> Int {
        if start == target { return 0 }
        var dist = [Int](repeating: GraphPathDijkstra.INF, count: graph.vertices)
        var visited = [Bool](repeating: false, count: graph.vertices)
        dist[start] = 0

        for _ in 0..<graph.vertices {
            var u = -1
            var minDist = GraphPathDijkstra.INF
            for v in 0..<graph.vertices {
                if !visited[v] && dist[v] < minDist {
                    minDist = dist[v]
                    u = v
                }
            }

            if u == -1 || minDist == GraphPathDijkstra.INF || u == target {
                return u == target ? minDist : -1
            }
            visited[u] = true

            for v in graph.adj[u] {
                let newDist = dist[u] + 1
                if newDist < dist[v] {
                    dist[v] = newDist
                }
            }
        }
        return -1
    }

    override func test() -> Int64 {
        var totalLength: Int64 = 0
        for (start, end) in pairs {
            let length = dijkstraShortestPath(start, end)
            totalLength += Int64(length)
        }
        return totalLength
    }
}