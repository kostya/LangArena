// MARK: - DFS Implementation
final class GraphPathDFS: GraphPathBenchmark {
    override func test() -> Int64 {
        var totalLength: Int64 = 0
        
        for (start, end) in pairs {
            let length = dfsFindPath(start, end)
            totalLength += Int64(length)
        }
        
        return totalLength
    }
    
    private func dfsFindPath(_ start: Int, _ target: Int) -> Int {
        // Как в Crystal: return 0 if start == target
        if start == target { return 0 }
        
        // Crystal: visited = Bytes.new(@graph.vertices)
        var visited = [Bool](repeating: false, count: graph.vertices)
        
        // Crystal: stack = [{start, 0}]
        var stack: [(Int, Int)] = [(start, 0)]
        
        // Crystal: best_path = Int32::MAX
        var bestPath = Int.max
        
        // ИСПРАВЛЕНО: В Crystal НЕТ visited[start] = 1 здесь!
        // visited[start] = true // <-- УБРАТЬ эту строку!
        
        while !stack.isEmpty {
            // Crystal: v, dist = stack.pop
            let (v, dist) = stack.removeLast()
            
            // Crystal: next if visited[v] == 1 || dist >= best_path
            if visited[v] || dist >= bestPath {
                continue
            }
            
            // Crystal: visited[v] = 1
            visited[v] = true
            
            // Обходим соседей в том порядке, в котором они хранятся (как в Crystal)
            for neighbor in graph.adj[v] {
                // Crystal: if neighbor == target
                if neighbor == target {
                    // Crystal: if dist + 1 < best_path
                    //          best_path = dist + 1
                    //          end
                    if dist + 1 < bestPath {
                        bestPath = dist + 1
                    }
                } else if !visited[neighbor] {
                    // Crystal: stack << {neighbor, dist + 1}
                    // НЕ отмечаем visited здесь! Только при извлечении из стека!
                    stack.append((neighbor, dist + 1))
                }
            }
        }
        
        // Crystal: best_path == Int32::MAX ? -1 : best_path
        return bestPath == Int.max ? -1 : bestPath
    }
}