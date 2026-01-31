import Foundation

final class GameOfLife: BenchmarkProtocol {
    private enum Cell: UInt8 {
        case dead = 0
        case alive = 1
    }
    
    private class Grid {
        let width: Int
        let height: Int
        private var cells: UnsafeMutableBufferPointer<UInt8>     // Плоский массив для производительности
        private var buffer: UnsafeMutableBufferPointer<UInt8>     // Предварительно аллоцированный буфер
        
        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            let size = width * height
            
            // Выделяем память для массивов
            let cellsPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            let bufferPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
            
            cells = UnsafeMutableBufferPointer(start: cellsPtr, count: size)
            buffer = UnsafeMutableBufferPointer(start: bufferPtr, count: size)
            
            // Инициализируем нулями
            cellsPtr.initialize(repeating: 0, count: size)
            bufferPtr.initialize(repeating: 0, count: size)
        }
        
        // Конструктор для обмена буферов
        private init(width: Int, height: Int, 
                    cells: UnsafeMutableBufferPointer<UInt8>,
                    buffer: UnsafeMutableBufferPointer<UInt8>) {
            self.width = width
            self.height = height
            self.cells = cells
            self.buffer = buffer
        }
        
        deinit {
            cells.baseAddress?.deallocate()
            buffer.baseAddress?.deallocate()
        }
        
        // Быстрый доступ по индексу
        @inline(__always)
        private func index(x: Int, y: Int) -> Int {
            return y * width + x
        }
        
        subscript(x: Int, y: Int) -> Cell {
            get {
                let idx = index(x: x, y: y)
                return cells[idx] == 1 ? .alive : .dead
            }
            set {
                let idx = index(x: x, y: y)
                cells[idx] = newValue.rawValue
            }
        }
        
        // Оптимизированный подсчет соседей
        @inline(__always)
        private func countNeighbors(x: Int, y: Int, cells: UnsafeBufferPointer<UInt8>) -> Int {
            // Предварительно вычисленные индексы с тороидальными границами
            let yPrev = y == 0 ? height - 1 : y - 1
            let yNext = y == height - 1 ? 0 : y + 1
            let xPrev = x == 0 ? width - 1 : x - 1
            let xNext = x == width - 1 ? 0 : x + 1
            
            // Развернутый подсчет 8 соседей
            var count = 0
            
            // Верхний ряд
            var idx = yPrev * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + x] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }
            
            // Средний ряд
            idx = y * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }
            
            // Нижний ряд
            idx = yNext * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + x] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }
            
            return count
        }
        
        func nextGeneration() -> Grid {
            let width = self.width
            let height = self.height
            
            // Локальные ссылки для производительности
            let currentCells = UnsafeBufferPointer(cells)
            let nextBuffer = buffer
            
            // Оптимизированный цикл
            for y in 0..<height {
                let yIdx = y * width
                
                for x in 0..<width {
                    let idx = yIdx + x
                    
                    // Подсчет соседей
                    let neighbors = countNeighbors(x: x, y: y, cells: currentCells)
                    
                    // Оптимизированная логика игры
                    let current = currentCells[idx]
                    let nextState: UInt8
                    
                    if current == 1 {
                        nextState = (neighbors == 2 || neighbors == 3) ? 1 : 0
                    } else {
                        nextState = (neighbors == 3) ? 1 : 0
                    }
                    
                    nextBuffer[idx] = nextState
                }
            }
            
            // Возвращаем новый Grid с обмененными буферами
            return Grid(width: width, height: height,
                       cells: buffer,
                       buffer: cells)
        }
        
        func computeHash() -> UInt32 {
            let FNV_OFFSET_BASIS: UInt32 = 2166136261
            let FNV_PRIME: UInt32 = 16777619
            
            var hasher = FNV_OFFSET_BASIS
            
            // Оптимизированный цикл хэширования
            for i in 0..<cells.count {
                let alive = UInt32(cells[i])
                hasher ^= alive
                hasher = hasher &* FNV_PRIME  // Безопасное умножение
            }
            
            return hasher
        }
    }
    
    private var resultVal: UInt32 = 0
    private var width: Int = 0
    private var height: Int = 0
    private var grid: Grid
    
    init() {
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
        
        // Оптимизированная инициализация случайными клетками
        for y in 0..<height {
            let yIdx = y * width
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
    
    var name: String {
        return "GameOfLife"
    }
}