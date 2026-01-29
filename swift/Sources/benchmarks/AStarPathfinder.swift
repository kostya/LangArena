import Foundation

final class AStarPathfinder: BenchmarkProtocol {
    private struct Node: Comparable {
        let x: Int
        let y: Int
        let fScore: Int
        
        static func < (lhs: Node, rhs: Node) -> Bool {
            if lhs.fScore != rhs.fScore {
                return lhs.fScore < rhs.fScore
            }
            if lhs.y != rhs.y {
                return lhs.y < rhs.y
            }
            return lhs.x < rhs.x
        }
    }
    
    private struct BinaryHeap<T: Comparable> {
        private var data: [T] = []
        
        var isEmpty: Bool { data.isEmpty }
        
        mutating func push(_ item: T) {
            data.append(item)
            siftUp(from: data.count - 1)
        }
        
        mutating func pop() -> T? {
            guard !data.isEmpty else { return nil }
            
            if data.count == 1 {
                return data.removeLast()
            }
            
            let result = data[0]
            data[0] = data.removeLast()
            siftDown(from: 0)
            return result
        }
        
        private mutating func siftUp(from index: Int) {
            var child = index
            var parent = (child - 1) / 2
            
            while child > 0 && data[child] < data[parent] {
                data.swapAt(child, parent)
                child = parent
                parent = (child - 1) / 2
            }
        }
        
        private mutating func siftDown(from index: Int) {
            var parent = index
            let count = data.count
            
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var candidate = parent
                
                if left < count && data[left] < data[candidate] {
                    candidate = left
                }
                
                if right < count && data[right] < data[candidate] {
                    candidate = right
                }
                
                if candidate == parent { break }
                
                data.swapAt(parent, candidate)
                parent = candidate
            }
        }
    }
    
    private func distance(ax: Int, ay: Int, bx: Int, by: Int) -> Int {
        return abs(ax - bx) + abs(ay - by)
    }
    
    private func findPath() -> (path: [(x: Int, y: Int)]?, nodesExplored: Int) {
        var grid = mazeGrid
        
        var gScores = Array(repeating: Array(repeating: Int.max, count: width), count: height)
        var cameFrom = Array(repeating: Array(repeating: (-1, -1), count: width), count: height)
        var openSet = BinaryHeap<Node>()
        var nodesExplored = 0
        
        gScores[startY][startX] = 0
        openSet.push(Node(x: startX, y: startY, 
                         fScore: distance(ax: startX, ay: startY, bx: goalX, by: goalY)))
        
        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        
        while let current = openSet.pop() {
            nodesExplored += 1
            
            if current.x == goalX && current.y == goalY {
                var path: [(x: Int, y: Int)] = []
                var x = current.x
                var y = current.y
                
                while x != startX || y != startY {
                    path.append((x, y))
                    let (px, py) = cameFrom[y][x]
                    x = px
                    y = py
                }
                
                path.append((startX, startY))
                path.reverse()
                return (path, nodesExplored)
            }
            
            let currentG = gScores[current.y][current.x]
            
            for (dx, dy) in directions {
                let nx = current.x + dx
                let ny = current.y + dy
                
                if nx < 0 || nx >= width || ny < 0 || ny >= height { continue }
                if !grid[ny][nx] { continue }
                
                let tentativeG = currentG + 1000
                
                if tentativeG < gScores[ny][nx] {
                    cameFrom[ny][nx] = (current.x, current.y)
                    gScores[ny][nx] = tentativeG
                    
                    let fScore = tentativeG + distance(ax: nx, ay: ny, bx: goalX, by: goalY)
                    openSet.push(Node(x: nx, y: ny, fScore: fScore))
                }
            }
        }
        
        return (nil, nodesExplored)
    }
    
    private var resultVal: UInt32 = 0
    private var startX: Int = 1
    private var startY: Int = 1
    private var goalX: Int = 0
    private var goalY: Int = 0
    private var width: Int = 0
    private var height: Int = 0
    private var mazeGrid: [[Bool]] = []
    
    init() {
        // Инициализация по умолчанию
    }
    
    func prepare() {
        // Получаем значения из конфига
        width = Int(configValue("w") ?? 50)
        height = Int(configValue("h") ?? 50)
        
        // Обновляем goalX/goalY на основе width/height
        goalX = width - 2
        goalY = height - 2
        
        // Генерируем лабиринт
        mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width: width, height: height)
    }
    
    func run(iterationId: Int) {
        let (path, nodesExplored) = findPath()
        
        var localResult: UInt32 = 0
        
        // КАК В C++: path.count БЕЗ деления на 2 (храним пары координат)
        let pathLength = UInt32(path?.count ?? 0)
        localResult = (localResult << 5) &+ pathLength
        localResult = (localResult << 5) &+ UInt32(nodesExplored)
        
        resultVal &+= localResult
    }
    
    var checksum: UInt32 {
        return resultVal
    }
}