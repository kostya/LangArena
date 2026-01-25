import Foundation

final class AStarPathfinder: BenchmarkProtocol {
    private protocol Heuristic {
        func distance(ax: Int, ay: Int, bx: Int, by: Int) -> Int
    }
    
    private struct ManhattanHeuristic: Heuristic {
        func distance(ax: Int, ay: Int, bx: Int, by: Int) -> Int {
            return (abs(ax - bx) + abs(ay - by)) * 1000
        }
    }
    
    private struct EuclideanHeuristic: Heuristic {
        func distance(ax: Int, ay: Int, bx: Int, by: Int) -> Int {
            let dx = Double(abs(ax - bx))
            let dy = Double(abs(ay - by))
            return Int(hypot(dx, dy) * 1000.0)
        }
    }
    
    private struct ChebyshevHeuristic: Heuristic {
        func distance(ax: Int, ay: Int, bx: Int, by: Int) -> Int {
            return max(abs(ax - bx), abs(ay - by)) * 1000
        }
    }
    
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
    
    private let startX: Int
    private let startY: Int
    private let goalX: Int
    private let goalY: Int
    private let width: Int
    private let height: Int
    private var mazeGrid: [[Bool]]?
    private var resultVal: Int64 = 0
    private let iterations: Int
    
    init() {
        let input = Helper.getInput("AStarPathfinder")
        let n = Int(input ?? "") ?? 5
        self.width = n
        self.height = n
        self.startX = 1
        self.startY = 1
        self.goalX = width - 2
        self.goalY = height - 2
        self.iterations = 10
    }
    
    func prepare() {
        ensureMazeGrid()
    }
    
    private func ensureMazeGrid() {
        if mazeGrid == nil {
            mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width: width, height: height)
        }
    }
    
    private func findPath(heuristic: Heuristic, allowDiagonal: Bool = false) -> [(x: Int, y: Int)]? {
        guard let grid = mazeGrid else { return nil }
        
        var gScores = Array(repeating: Array(repeating: Int.max, count: width), count: height)
        var cameFrom = Array(repeating: Array(repeating: (-1, -1), count: width), count: height)
        var openSet = BinaryHeap<Node>()
        
        gScores[startY][startX] = 0
        openSet.push(Node(x: startX, y: startY, 
                         fScore: heuristic.distance(ax: startX, ay: startY, bx: goalX, by: goalY)))
        
        let directions: [(dx: Int, dy: Int)] = allowDiagonal ? 
            [(0, -1), (1, 0), (0, 1), (-1, 0), (-1, -1), (1, -1), (1, 1), (-1, 1)] :
            [(0, -1), (1, 0), (0, 1), (-1, 0)]
        
        let diagonalCost = allowDiagonal ? 1414 : 1000
        
        while let current = openSet.pop() {
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
                return path.reversed()
            }
            
            let currentG = gScores[current.y][current.x]
            
            for (dx, dy) in directions {
                let nx = current.x + dx
                let ny = current.y + dy
                
                if nx < 0 || nx >= width || ny < 0 || ny >= height { continue }
                if !grid[ny][nx] { continue }
                
                let moveCost = (abs(dx) == 1 && abs(dy) == 1) ? diagonalCost : 1000
                let tentativeG = currentG + moveCost
                
                if tentativeG < gScores[ny][nx] {
                    cameFrom[ny][nx] = (current.x, current.y)
                    gScores[ny][nx] = tentativeG
                    
                    let fScore = tentativeG + heuristic.distance(ax: nx, ay: ny, bx: goalX, by: goalY)
                    openSet.push(Node(x: nx, y: ny, fScore: fScore))
                }
            }
        }
        
        return nil
    }
    
    private func estimateNodesExplored(heuristic: Heuristic, allowDiagonal: Bool = false) -> Int {
        guard let grid = mazeGrid else { return 0 }
        
        var gScores = Array(repeating: Array(repeating: Int.max, count: width), count: height)
        var openSet = BinaryHeap<Node>()
        var closed = Array(repeating: Array(repeating: false, count: width), count: height)
        
        gScores[startY][startX] = 0
        openSet.push(Node(x: startX, y: startY, 
                         fScore: heuristic.distance(ax: startX, ay: startY, bx: goalX, by: goalY)))
        
        let directions: [(dx: Int, dy: Int)] = allowDiagonal ? 
            [(0, -1), (1, 0), (0, 1), (-1, 0), (-1, -1), (1, -1), (1, 1), (-1, 1)] :
            [(0, -1), (1, 0), (0, 1), (-1, 0)]
        
        var nodesExplored = 0
        
        while let current = openSet.pop() {
            if current.x == goalX && current.y == goalY {
                break
            }
            
            if closed[current.y][current.x] { continue }
            
            closed[current.y][current.x] = true
            nodesExplored += 1
            
            let currentG = gScores[current.y][current.x]
            
            for (dx, dy) in directions {
                let nx = current.x + dx
                let ny = current.y + dy
                
                if nx < 0 || nx >= width || ny < 0 || ny >= height { continue }
                if !grid[ny][nx] { continue }
                
                let moveCost = (abs(dx) == 1 && abs(dy) == 1) ? 1414 : 1000
                let tentativeG = currentG + moveCost
                
                if tentativeG < gScores[ny][nx] {
                    gScores[ny][nx] = tentativeG
                    
                    let fScore = tentativeG + heuristic.distance(ax: nx, ay: ny, bx: goalX, by: goalY)
                    openSet.push(Node(x: nx, y: ny, fScore: fScore))
                }
            }
        }
        
        return nodesExplored
    }
    
    private func benchmarkDifferentApproaches() -> (pathsFound: Int, pathLength: Int, nodesExplored: Int) {
        let heuristics: [Heuristic] = [
            ManhattanHeuristic(),
            EuclideanHeuristic(),
            ChebyshevHeuristic()
        ]
        
        var totalPathsFound = 0
        var totalPathLength = 0
        var totalNodesExplored = 0
        
        for heuristic in heuristics {
            if let path = findPath(heuristic: heuristic, allowDiagonal: false) {
                totalPathsFound += 1
                totalPathLength += path.count
                totalNodesExplored += estimateNodesExplored(heuristic: heuristic, allowDiagonal: false)
            }
        }
        
        return (totalPathsFound, totalPathLength, totalNodesExplored)
    }
    
    func run() {
        var totalPathsFound = 0
        var totalPathLength = 0
        var totalNodesExplored = 0
        
        for _ in 0..<iterations {
            let (pathsFound, pathLength, nodesExplored) = benchmarkDifferentApproaches()
            
            totalPathsFound += pathsFound
            totalPathLength += pathLength
            totalNodesExplored += nodesExplored
        }
        
        let pathsChecksum = Helper.checksumF64(Double(totalPathsFound))
        let lengthChecksum = Helper.checksumF64(Double(totalPathLength))
        let nodesChecksum = Helper.checksumF64(Double(totalNodesExplored))
        
        resultVal = Int64(pathsChecksum) ^
                   (Int64(lengthChecksum) << 16) ^
                   (Int64(nodesChecksum) << 32)
    }
    
    var result: Int64 {
        return resultVal
    }
}