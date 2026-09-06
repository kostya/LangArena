package benchmarks

import Benchmark

class GameOfLife : Benchmark() {
    private class Cell {
        var alive = false
        var nextState = false
        lateinit var neighbors: Array<Cell>

        fun computeNextState() {
            val aliveNeighbors = neighbors.count { it.alive }

            nextState =
                if (alive) {
                    aliveNeighbors == 2 || aliveNeighbors == 3
                } else {
                    aliveNeighbors == 3
                }
        }

        fun update() {
            alive = nextState
        }
    }

    private class Grid(
        private val width: Int,
        private val height: Int,
    ) {
        val cells = Array(height) { Array(width) { Cell() } }

        init {
            linkNeighbors()
        }

        private fun linkNeighbors() {
            for (y in 0 until height) {
                for (x in 0 until width) {
                    cells[y][x].neighbors =
                        buildList {
                            for (dy in -1..1) {
                                for (dx in -1..1) {
                                    if (dx == 0 && dy == 0) continue

                                    val ny = (y + dy + height) % height
                                    val nx = (x + dx + width) % width
                                    add(cells[ny][nx])
                                }
                            }
                        }.toTypedArray()
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

        fun countAlive(): Int = cells.sumOf { row -> row.count { it.alive } }

        fun computeHash(): UInt {
            var hasher = 2166136261uL
            val prime = 16777619uL

            for (row in cells) {
                for (cell in row) {
                    val alive = if (cell.alive) 1uL else 0uL
                    hasher = (hasher xor alive) * prime
                }
            }

            return hasher.toUInt()
        }
    }

    private val width = configInt("w")
    private val height = configInt("h")
    private lateinit var grid: Grid

    override fun prepare() {
        grid = Grid(width, height)

        for (row in grid.cells) {
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

    override fun name(): String = "Etc::GameOfLife"
}
