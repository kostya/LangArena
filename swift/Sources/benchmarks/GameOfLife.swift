import Foundation

final class GameOfLife: BenchmarkProtocol {
    private final class Cell {
        var alive: Bool = false
        var nextState: Bool = false
        var neighbors: [Cell] = []

        func addNeighbor(_ cell: Cell) {
            neighbors.append(cell)
        }

        func computeNextState() {
            var aliveNeighbors = 0
            for neighbor in neighbors {
                if neighbor.alive { aliveNeighbors += 1 }
            }

            if alive {
                nextState = aliveNeighbors == 2 || aliveNeighbors == 3
            } else {
                nextState = aliveNeighbors == 3
            }
        }

        func update() {
            alive = nextState
        }
    }

    private final class Grid {
        let width: Int
        let height: Int
        private var cells: [[Cell]]

        init(width: Int, height: Int) {
            self.width = width
            self.height = height

            cells = (0..<height).map { y in
                (0..<width).map { x in
                    Cell()
                }
            }

            linkNeighbors()
        }

        private func linkNeighbors() {
            for y in 0..<height {
                for x in 0..<width {
                    let cell = cells[y][x]

                    for dy in -1...1 {
                        for dx in -1...1 {
                            if dx == 0 && dy == 0 { continue }

                            let ny = (y + dy + height) % height
                            let nx = (x + dx + width) % width

                            cell.addNeighbor(cells[ny][nx])
                        }
                    }
                }
            }
        }

        func nextGeneration() {

            for row in cells {
                for cell in row {
                    cell.computeNextState()
                }
            }

            for row in cells {
                for cell in row {
                    cell.update()
                }
            }
        }

        func countAlive() -> Int {
            return cells.reduce(0) { total, row in
                total + row.filter { $0.alive }.count
            }
        }

        func computeHash() -> UInt32 {
            let FNV_OFFSET_BASIS: UInt32 = 2166136261
            let FNV_PRIME: UInt32 = 16777619

            var hasher = FNV_OFFSET_BASIS

            for row in cells {
                for cell in row {
                    let alive = cell.alive ? UInt32(1) : UInt32(0)
                    hasher ^= alive
                    hasher = hasher &* FNV_PRIME
                }
            }

            return hasher
        }

        subscript(x: Int, y: Int) -> Cell {
            return cells[y][x]
        }
    }

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
        self.grid = Grid(width: width, height: height)

        for y in 0..<height {
            for x in 0..<width {
                if Helper.nextFloat() < 0.1 {
                    grid[x, y].alive = true
                }
            }
        }
    }

    func run(iterationId: Int) {
        grid.nextGeneration()
    }

    var checksum: UInt32 {
        let alive = grid.countAlive()
        return grid.computeHash() + UInt32(alive)
    }

    var name: String {
        return "GameOfLife"
    }
}