import Foundation

final class GameOfLife: BenchmarkProtocol {
    private enum Cell {
        case dead
        case alive
    }
    
    private class Grid {
        private let width: Int
        private let height: Int
        private var cells: [[Cell]]
        
        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            self.cells = Array(repeating: Array(repeating: .dead, count: width), 
                              count: height)
        }
        
        func get(x: Int, y: Int) -> Cell {
            return cells[y][x]
        }
        
        func set(x: Int, y: Int, cell: Cell) {
            cells[y][x] = cell
        }
        
        private func toroidal(_ value: Int, modulo: Int) -> Int {
            var result = value % modulo
            if result < 0 {
                result += modulo
            }
            return result
        }
        
        func countNeighbors(x: Int, y: Int) -> Int {
            var count = 0
            
            for dy in -1...1 {
                for dx in -1...1 {
                    if dx == 0 && dy == 0 { continue }
                    
                    // Тороидальные координаты
                    let nx = toroidal(x + dx, modulo: width)
                    let ny = toroidal(y + dy, modulo: height)
                    
                    if cells[ny][nx] == .alive {
                        count += 1
                    }
                }
            }
            
            return count
        }
        
        func nextGeneration() -> Grid {
            let nextGrid = Grid(width: width, height: height)
            
            for y in 0..<height {
                for x in 0..<width {
                    let neighbors = countNeighbors(x: x, y: y)
                    let current = cells[y][x]
                    
                    var nextState: Cell = .dead
                    if current == .alive {
                        if neighbors == 2 || neighbors == 3 {
                            nextState = .alive
                        }
                    } else {
                        if neighbors == 3 {
                            nextState = .alive
                        }
                    }
                    
                    nextGrid.cells[y][x] = nextState
                }
            }
            
            return nextGrid
        }
        
        func aliveCount() -> Int {
            var count = 0
            for row in cells {
                for cell in row {
                    if cell == .alive {
                        count += 1
                    }
                }
            }
            return count
        }
        
        func computeHash() -> UInt64 {
            var hasher: UInt64 = 0
            for row in cells {
                for cell in row {
                    // Простой хэш - сдвиг и XOR
                    hasher = (hasher << 1) ^ (cell == .alive ? 1 : 0)
                }
            }
            return hasher
        }
    }
    
    private var resultVal: Int64 = 0
    private let width: Int
    private let height: Int
    private var grid: Grid
    
    init() {
        self.width = 256
        self.height = 256
        self.grid = Grid(width: width, height: height)
    }
    
    func prepare() {
        resultVal = 0
    }
    
    func run() {
        // Инициализация случайными клетками
        for y in 0..<height {
            for x in 0..<width {
                if Helper.nextFloat() < 0.1 {
                    grid.set(x: x, y: y, cell: .alive)
                }
            }
        }
        
        // Основной цикл симуляции
        let iters = iterations
        for _ in 0..<iters {
            grid = grid.nextGeneration()
        }
        
        resultVal = Int64(grid.aliveCount())
    }
    
    var result: Int64 {
        return resultVal
    }
    
    // Нужно добавить свойство iterations (должно быть в BenchmarkProtocol)
    var iterations: Int {
        // По аналогии с другими бенчмарками
        let input = Helper.getInput("GameOfLife")
        return Int(input ?? "") ?? 100
    }
}