package benchmarks

import Benchmark

class GameOfLife : Benchmark() {
    private enum class Cell {
        DEAD, ALIVE
    }
    
    private class Grid(private val width: Int, private val height: Int) {
        private val cells = Array(height) { Array(width) { Cell.DEAD } }
        
        fun get(x: Int, y: Int): Cell = cells[y][x]
        fun set(x: Int, y: Int, cell: Cell) {
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
        
        fun aliveCount(): Int {
            var count = 0
            for (row in cells) {
                for (cell in row) {
                    if (cell == Cell.ALIVE) {
                        count++
                    }
                }
            }
            return count
        }
        
        fun computeHash(): Long {
            var hasher = 0L
            for (row in cells) {
                for (cell in row) {
                    // Простой хэш - сдвиг и XOR
                    hasher = (hasher shl 1) xor if (cell == Cell.ALIVE) 1L else 0L
                }
            }
            return hasher
        }
    }
    
    private var resultVal: Long = 0L
    private val width = 256
    private val height = 256
    private lateinit var grid: Grid
    
    override fun prepare() {
        grid = Grid(width, height)
        
        // Инициализация случайными клетками
        for (y in 0 until height) {
            for (x in 0 until width) {
                if (Helper.nextFloat() < 0.1f) {
                    grid.set(x, y, Cell.ALIVE)
                }
            }
        }
    }
    
    override fun run() {
        // Основной цикл симуляции
        val iters = iterations
        for (i in 0 until iters) {
            grid = grid.nextGeneration()
        }
        
        resultVal = grid.aliveCount().toLong()
    }
    
    override val result: Long
        get() = resultVal
}