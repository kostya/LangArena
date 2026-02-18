package benchmarks

import Benchmark

class GameOfLife : Benchmark() {

    private class Cell {
        var alive: Boolean = false
        var nextState: Boolean = false
        val neighbors = arrayOfNulls<Cell>(8)
        var neighborCount = 0

        fun addNeighbor(cell: Cell) {
            neighbors[neighborCount++] = cell
        }

        fun computeNextState() {
            var aliveNeighbors = 0
            for (neighbor in neighbors) {
                if (neighbor!!.alive) aliveNeighbors++
            }

            nextState = if (alive) {
                aliveNeighbors == 2 || aliveNeighbors == 3
            } else {
                aliveNeighbors == 3
            }
        }

        fun update() {
            alive = nextState
        }
    }

    private class Grid(private val width: Int, private val height: Int) {
        private val cells: List<List<Cell>>

        init {

            cells = List(height) { y ->
                List(width) { x ->
                    Cell()
                }
            }
            linkNeighbors()
        }

        private fun linkNeighbors() {
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val cell = cells[y][x]

                    for (dy in -1..1) {
                        for (dx in -1..1) {
                            if (dx == 0 && dy == 0) continue

                            val ny = (y + dy + height) % height
                            val nx = (x + dx + width) % width

                            cell.addNeighbor(cells[ny][nx])
                        }
                    }
                }
            }
        }

        fun nextGeneration() {

            for (row in cells) {
                for (cell in row) {
                    cell.computeNextState()
                }
            }

            for (row in cells) {
                for (cell in row) {
                    cell.update()
                }
            }
        }

        fun countAlive(): Int {
            return cells.sumOf { row -> row.count { it.alive } }
        }

        fun computeHash(): UInt {
            val FNV_OFFSET_BASIS: ULong = 2166136261UL
            val FNV_PRIME: ULong = 16777619UL

            var hasher = FNV_OFFSET_BASIS

            for (row in cells) {
                for (cell in row) {
                    val alive = if (cell.alive) 1UL else 0UL
                    hasher = (hasher xor alive) * FNV_PRIME
                }
            }

            return hasher.toUInt()
        }

        fun getCells(): List<List<Cell>> = cells
    }

    private val width: Int
    private val height: Int
    private lateinit var grid: Grid

    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
    }

    override fun prepare() {
        grid = Grid(width, height)

        for (row in grid.getCells()) {
            for (cell in row) {
                if (Helper.nextFloat() < 0.1f) {
                    cell.alive = true
                }
            }
        }
    }

    override fun run(iterationId: Int) {
        grid.nextGeneration()
    }

    override fun checksum(): UInt {
        val alive = grid.countAlive()
        return grid.computeHash() + alive.toUInt()
    }

    override fun name(): String = "GameOfLife"
}