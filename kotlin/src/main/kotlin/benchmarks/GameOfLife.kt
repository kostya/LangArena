package benchmarks

import Benchmark

class GameOfLife : Benchmark() {
    private enum class Cell {
        DEAD, ALIVE
    }

    private class Grid(private val width: Int, private val height: Int) {

        private var cells: ByteArray
        private var buffer: ByteArray  

        init {
            val size = width * height
            cells = ByteArray(size)
            buffer = ByteArray(size)
        }

        private constructor(width: Int, height: Int, cells: ByteArray, buffer: ByteArray) : this(width, height) {
            this.cells = cells
            this.buffer = buffer
        }

        private fun index(x: Int, y: Int): Int = y * width + x

        operator fun get(x: Int, y: Int): Cell = 
            if (cells[index(x, y)] == 1.toByte()) Cell.ALIVE else Cell.DEAD

        operator fun set(x: Int, y: Int, cell: Cell) {
            cells[index(x, y)] = if (cell == Cell.ALIVE) 1 else 0
        }

        private fun countNeighbors(x: Int, y: Int, cells: ByteArray): Int {

            val yPrev = if (y == 0) height - 1 else y - 1
            val yNext = if (y == height - 1) 0 else y + 1
            val xPrev = if (x == 0) width - 1 else x - 1
            val xNext = if (x == width - 1) 0 else x + 1

            var count = 0

            var idx = yPrev * width
            if (cells[idx + xPrev] == 1.toByte()) count++
            if (cells[idx + x] == 1.toByte()) count++
            if (cells[idx + xNext] == 1.toByte()) count++

            idx = y * width
            if (cells[idx + xPrev] == 1.toByte()) count++
            if (cells[idx + xNext] == 1.toByte()) count++

            idx = yNext * width
            if (cells[idx + xPrev] == 1.toByte()) count++
            if (cells[idx + x] == 1.toByte()) count++
            if (cells[idx + xNext] == 1.toByte()) count++

            return count
        }

        fun nextGeneration(): Grid {

            val w = width
            val h = height
            val currentCells = cells
            val nextCells = buffer

            for (y in 0 until h) {
                val yIdx = y * w

                for (x in 0 until w) {
                    val idx = yIdx + x

                    val neighbors = countNeighbors(x, y, currentCells)

                    val current = currentCells[idx]
                    val nextState = when {
                        current == 1.toByte() && (neighbors == 2 || neighbors == 3) -> 1.toByte()
                        current == 0.toByte() && neighbors == 3 -> 1.toByte()
                        else -> 0.toByte()
                    }

                    nextCells[idx] = nextState
                }
            }

            return Grid(w, h, nextCells, currentCells)
        }

        fun computeHash(): UInt {
            val FNV_OFFSET_BASIS: ULong = 2166136261UL
            val FNV_PRIME: ULong = 16777619UL

            var hasher = FNV_OFFSET_BASIS

            for (i in cells.indices) {
                val alive = if (cells[i] == 1.toByte()) 1UL else 0UL
                hasher = (hasher xor alive) * FNV_PRIME
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

        for (y in 0 until height) {
            val yIdx = y * width
            for (x in 0 until width) {
                if (Helper.nextFloat() < 0.1f) {
                    grid[x, y] = Cell.ALIVE
                }
            }
        }
    }

    override fun run(iterationId: Int) {

        grid = grid.nextGeneration()
    }

    override fun checksum(): UInt = grid.computeHash()

    override fun name(): String = "GameOfLife"
}