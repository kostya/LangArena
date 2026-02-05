import Foundation

final class GameOfLife: BenchmarkProtocol {
    private enum Cell: UInt8 {
        case dead = 0
        case alive = 1
    }

    private class Grid {
        let width: Int
        let height: Int
        private var cells: [UInt8]          
        private var buffer: [UInt8]         

        init(width: Int, height: Int) {
            self.width = width
            self.height = height
            let size = width * height

            self.cells = [UInt8](repeating: 0, count: size)
            self.buffer = [UInt8](repeating: 0, count: size)
        }

        private init(width: Int, height: Int, cells: [UInt8], buffer: [UInt8]) {
            self.width = width
            self.height = height
            self.cells = cells
            self.buffer = buffer
        }

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

        @inline(__always)
        private func countNeighbors(x: Int, y: Int, cells: [UInt8]) -> Int {

            let yPrev = y == 0 ? height - 1 : y - 1
            let yNext = y == height - 1 ? 0 : y + 1
            let xPrev = x == 0 ? width - 1 : x - 1
            let xNext = x == width - 1 ? 0 : x + 1

            var count = 0

            var idx = yPrev * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + x] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }

            idx = y * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }

            idx = yNext * width
            if cells[idx + xPrev] == 1 { count += 1 }
            if cells[idx + x] == 1 { count += 1 }
            if cells[idx + xNext] == 1 { count += 1 }

            return count
        }

        func nextGeneration() -> Grid {
            let width = self.width
            let height = self.height

            var nextCells = buffer 

            for y in 0..<height {
                let yIdx = y * width

                for x in 0..<width {
                    let idx = yIdx + x

                    let neighbors = countNeighbors(x: x, y: y, cells: cells)

                    let current = cells[idx]
                    let nextState: UInt8

                    if current == 1 {
                        nextState = (neighbors == 2 || neighbors == 3) ? 1 : 0
                    } else {
                        nextState = (neighbors == 3) ? 1 : 0
                    }

                    nextCells[idx] = nextState
                }
            }

            return Grid(width: width, height: height,
                       cells: nextCells,
                       buffer: cells)
        }

        func computeHash() -> UInt32 {
            let FNV_OFFSET_BASIS: UInt32 = 2166136261
            let FNV_PRIME: UInt32 = 16777619

            var hasher = FNV_OFFSET_BASIS

            for i in 0..<cells.count {
                let alive = UInt32(cells[i])
                hasher ^= alive
                hasher = hasher &* FNV_PRIME  
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

        let configW = Int(configValue("w") ?? 256)
        let configH = Int(configValue("h") ?? 256)

        self.width = configW
        self.height = configH
        let newGrid = Grid(width: width, height: height)

        for y in 0..<height {
            let yIdx = y * width
            for x in 0..<width {
                if Helper.nextFloat() < 0.1 {
                    newGrid[x, y] = .alive
                }
            }
        }

        self.grid = newGrid
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