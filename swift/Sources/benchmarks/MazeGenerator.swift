import Foundation

final class MazeGenerator: BenchmarkProtocol {
    public enum MazeCell {
        case wall
        case path
    }
    
    public class Maze {
        private let width: Int
        private let height: Int
        private var cells: [[MazeCell]]
        
        init(width: Int, height: Int) {
            self.width = width > 5 ? width : 5
            self.height = height > 5 ? height : 5
            self.cells = Array(repeating: Array(repeating: .wall, count: self.width), 
                              count: self.height)
        }
        
        subscript(x: Int, y: Int) -> MazeCell {
            get {
                return cells[y][x]
            }
            set {
                cells[y][x] = newValue
            }
        }
        
        private func divide(x1: Int, y1: Int, x2: Int, y2: Int) {
            let width = x2 - x1
            let height = y2 - y1
            
            if width < 2 || height < 2 {
                return
            }
            
            let widthForWall = max(width - 2, 0)
            let heightForWall = max(height - 2, 0)
            let widthForHole = max(width - 1, 0)
            let heightForHole = max(height - 1, 0)
            
            if widthForWall == 0 || heightForWall == 0 ||
               widthForHole == 0 || heightForHole == 0 {
                return
            }
            
            if width > height {
                // Вертикальная стена
                let wallRange = max(widthForWall / 2, 1)
                let wallOffset = wallRange > 0 ? (Helper.nextInt(max: wallRange)) * 2 : 0
                let wallX = x1 + 2 + wallOffset
                
                let holeRange = max(heightForHole / 2, 1)
                let holeOffset = holeRange > 0 ? (Helper.nextInt(max: holeRange)) * 2 : 0
                let holeY = y1 + 1 + holeOffset
                
                if wallX > x2 || holeY > y2 {
                    return
                }
                
                for y in y1...y2 {
                    if y != holeY {
                        self[wallX, y] = .wall
                    }
                }
                
                if wallX > x1 + 1 {
                    divide(x1: x1, y1: y1, x2: wallX - 1, y2: y2)
                }
                if wallX + 1 < x2 {
                    divide(x1: wallX + 1, y1: y1, x2: x2, y2: y2)
                }
            } else {
                // Горизонтальная стена
                let wallRange = max(heightForWall / 2, 1)
                let wallOffset = wallRange > 0 ? (Helper.nextInt(max: wallRange)) * 2 : 0
                let wallY = y1 + 2 + wallOffset
                
                let holeRange = max(widthForHole / 2, 1)
                let holeOffset = holeRange > 0 ? (Helper.nextInt(max: holeRange)) * 2 : 0
                let holeX = x1 + 1 + holeOffset
                
                if wallY > y2 || holeX > x2 {
                    return
                }
                
                for x in x1...x2 {
                    if x != holeX {
                        self[x, wallY] = .wall
                    }
                }
                
                if wallY > y1 + 1 {
                    divide(x1: x1, y1: y1, x2: x2, y2: wallY - 1)
                }
                if wallY + 1 < y2 {
                    divide(x1: x1, y1: wallY + 1, x2: x2, y2: y2)
                }
            }
        }
        
        private func isConnected(startX: Int, startY: Int, goalX: Int, goalY: Int) -> Bool {
            if startX >= width || startY >= height ||
               goalX >= width || goalY >= height {
                return false
            }
            
            var visited = Array(repeating: Array(repeating: false, count: width), 
                               count: height)
            var queue: [(x: Int, y: Int)] = [(startX, startY)]
            visited[startY][startX] = true
            
            while !queue.isEmpty {
                let (x, y) = queue.removeFirst()
                
                if x == goalX && y == goalY {
                    return true
                }
                
                // Верх
                if y > 0 && self[x, y - 1] == .path && !visited[y - 1][x] {
                    visited[y - 1][x] = true
                    queue.append((x, y - 1))
                }
                
                // Право
                if x + 1 < width && self[x + 1, y] == .path && !visited[y][x + 1] {
                    visited[y][x + 1] = true
                    queue.append((x + 1, y))
                }
                
                // Низ
                if y + 1 < height && self[x, y + 1] == .path && !visited[y + 1][x] {
                    visited[y + 1][x] = true
                    queue.append((x, y + 1))
                }
                
                // Лево
                if x > 0 && self[x - 1, y] == .path && !visited[y][x - 1] {
                    visited[y][x - 1] = true
                    queue.append((x - 1, y))
                }
            }
            
            return false
        }
        
        func generate() {
            if width < 5 || height < 5 {
                for x in 0..<width {
                    self[x, height / 2] = .path
                }
                return
            }
            
            divide(x1: 0, y1: 0, x2: width - 1, y2: height - 1)
        }
        
        func toBoolGrid() -> [[Bool]] {
            var result = Array(repeating: Array(repeating: false, count: width), 
                              count: height)
            for y in 0..<height {
                for x in 0..<width {
                    result[y][x] = (self[x, y] == .path)
                }
            }
            return result
        }
        
        static func generateWalkableMaze(width: Int, height: Int) -> [[Bool]] {
            let maze = Maze(width: width, height: height)
            maze.generate()
            
            let startX = 1, startY = 1
            let goalX = width - 2, goalY = height - 2
            
            if !maze.isConnected(startX: startX, startY: startY, 
                                goalX: goalX, goalY: goalY) {
                for x in 0..<width {
                    for y in 0..<height {
                        if x < maze.width && y < maze.height {
                            if x == 1 || y == 1 || x == width - 2 || y == height - 2 {
                                maze[x, y] = .path
                            }
                        }
                    }
                }
            }
            
            return maze.toBoolGrid()
        }
    }
    
    private var resultVal: Int64 = 0
    private let width: Int
    private let height: Int
    private let iterations: Int
    
    init() {
        let input = Helper.getInput("MazeGenerator")
        self.iterations = Int(input ?? "100") ?? 100
        self.width = 1001
        self.height = 1001
    }
    
    func prepare() {
        resultVal = 0
    }
    
    func run() {
        var checksum: UInt64 = 0
        
        for _ in 0..<iterations {
            let boolGrid = Maze.generateWalkableMaze(width: width, height: height)
            
            // Простая checksum для сравнения
            for y in 0..<height {
                for x in 0..<width {
                    if !boolGrid[y][x] {
                        checksum = checksum &+ UInt64(x &* y)
                    }
                }
            }
        }
        
        resultVal = Int64(checksum)
    }
    
    var result: Int64 {
        return resultVal
    }
}