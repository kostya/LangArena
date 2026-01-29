package benchmarks

import Benchmark

class GameOfLife : Benchmark() {
    private enum class Cell {
        DEAD, ALIVE
    }
    
    private class Grid(private val width: Int, private val height: Int) {
        private val cells = Array(height) { Array(width) { Cell.DEAD } }
        
        operator fun get(x: Int, y: Int): Cell = cells[y][x]
        operator fun set(x: Int, y: Int, cell: Cell) {
            cells[y][x] = cell
        }
        
        fun countNeighbors(x: Int, y: Int): Int {
            var count = 0
            
            for (dy in -1..1) {
                for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    
                    // Тороидальные координаты
                    var nx = (x + dx) % width
                    var ny = (y + dy) % height
                    if (nx < 0) nx += width
                    if (ny < 0) ny += height
                    
                    if (cells[ny][nx] == Cell.ALIVE) {
                        count++
                    }
                }
            }
            
            return count
        }
        
        fun nextGeneration(): Grid {
            val nextGrid = Grid(width, height)
            
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val neighbors = countNeighbors(x, y)
                    val current = cells[y][x]
                    
                    val nextState = when {
                        current == Cell.ALIVE && (neighbors == 2 || neighbors == 3) -> Cell.ALIVE
                        current == Cell.DEAD && neighbors == 3 -> Cell.ALIVE
                        else -> Cell.DEAD
                    }
                    
                    nextGrid.cells[y][x] = nextState
                }
            }
            
            return nextGrid
        }
        
        fun computeHash(): UInt {
            var hasher = 2166136261UL      // FNV offset basis
            val prime = 16777619UL         // FNV prime
            
            for (row in cells) {
                for (cell in row) {
                    val alive = if (cell == Cell.ALIVE) 1UL else 0UL
                    hasher = (hasher xor alive) * prime
                }
            }
            return hasher.toUInt()
        }
    }
    
    private var resultVal: UInt = 0u
    private val width: Int
    private val height: Int
    private lateinit var grid: Grid
    
    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
    }
    
    override fun prepare() {
        grid = Grid(width, height)
        
        // Инициализация случайными клетками
        for (y in 0 until height) {
            for (x in 0 until width) {
                if (Helper.nextFloat() < 0.1f) {
                    grid[x, y] = Cell.ALIVE
                }
            }
        }
    }
    
    override fun run(iterationId: Int) {
        // Только одна итерация
        grid = grid.nextGeneration()
    }
    
    override fun checksum(): UInt = grid.computeHash()
    
    override fun name(): String = "GameOfLife"
}