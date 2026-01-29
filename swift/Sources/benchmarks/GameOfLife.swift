import Foundation

final class GameOfLife: BenchmarkProtocol {
    private enum Cell {
        case dead
        case alive
    }
    
    private class Grid {
        public let width: Int
        public let height: Int
        public var cells: [[Cell]]
        
        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            self.cells = Array(repeating: Array(repeating: .dead, count: width), 
                              count: height)
        }
        
        private func toroidal(_ value: Int, modulo: Int) -> Int {
            // Более надежная реализация
            return (value % modulo + modulo) % modulo
        }
        
        func countNeighbors(x: Int, y: Int) -> Int {
            var count = 0
            
            for dy in -1...1 {
                for dx in -1...1 {
                    if dx == 0 && dy == 0 { continue }
                    
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
            
            // Параллельное вычисление для производительности
            for y in 0..<height {
                for x in 0..<width {
                    let neighbors = countNeighbors(x: x, y: y)
                    let current = cells[y][x]
                    
                    let nextState: Cell
                    switch (current, neighbors) {
                    case (.alive, 2), (.alive, 3):
                        nextState = .alive
                    case (.dead, 3):
                        nextState = .alive
                    default:
                        nextState = .dead
                    }
                    
                    nextGrid.cells[y][x] = nextState
                }
            }
            
            return nextGrid
        }
        
        func computeHash() -> UInt32 {
            var hasher: UInt32 = 2166136261
            let prime: UInt32 = 16777619
            
            for row in cells {
                for cell in row {
                    let alive: UInt32 = (cell == .alive) ? 1 : 0
                    hasher = hasher ^ alive
                    hasher = hasher &* prime  // Безопасное умножение
                }
            }
            return hasher
        }
                
        subscript(x: Int, y: Int) -> Cell {
            get { 
                guard y >= 0 && y < height && x >= 0 && x < width else {
                    return .dead
                }
                return cells[y][x] 
            }
            set { 
                guard y >= 0 && y < height && x >= 0 && x < width else { return }
                cells[y][x] = newValue 
            }
        }
    }
    
    private var resultVal: UInt32 = 0
    private var width: Int = 0
    private var height: Int = 0
    private var grid: Grid
    
    init() {
        // Инициализируем нулевыми размерами
        self.width = 0
        self.height = 0
        self.grid = Grid(width: 0, height: 0)
    }
    
    func prepare() {
        // Получаем конфигурацию
        let configW = Int(configValue("w") ?? 10)
        let configH = Int(configValue("h") ?? 10)
        
        // Обновляем размеры если изменились
        if configW != width || configH != height {
            self.width = configW
            self.height = configH
            self.grid = Grid(width: width, height: height)
        }
        
        // Инициализируем случайные живые клетки
        for y in 0..<height {
            for x in 0..<width {
                if Helper.nextFloat() < 0.1 {
                    grid[x, y] = .alive
                }
            }
        }
    }
    
    func run(iterationId: Int) {
        grid = grid.nextGeneration()
    }
    
    var checksum: UInt32 {
        return grid.computeHash()
    }
}