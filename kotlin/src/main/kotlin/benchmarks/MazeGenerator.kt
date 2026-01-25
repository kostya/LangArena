package benchmarks

import Benchmark
import java.util.*

class MazeGenerator : Benchmark() {
    public enum class Cell {
        WALL, PATH
    }
    
    public class Maze(private val width: Int, private val height: Int) {
        private val cells = Array(height) { Array(width) { Cell.WALL } }
        
        fun get(x: Int, y: Int): Cell = cells[y][x]
        fun set(x: Int, y: Int, cell: Cell) {
            cells[y][x] = cell
        }
        
        private fun divide(x1: Int, y1: Int, x2: Int, y2: Int) {
            val width = x2 - x1
            val height = y2 - y1
            
            if (width < 2 || height < 2) return
            
            val widthForWall = maxOf(width - 2, 0)
            val heightForWall = maxOf(height - 2, 0)
            val widthForHole = maxOf(width - 1, 0)
            val heightForHole = maxOf(height - 1, 0)
            
            if (widthForWall == 0 || heightForWall == 0 ||
                widthForHole == 0 || heightForHole == 0) return
            
            if (width > height) {
                // Вертикальная стена
                val wallRange = maxOf(widthForWall / 2, 1)
                val wallOffset = if (wallRange > 0) Helper.nextInt(wallRange) * 2 else 0
                val wallX = x1 + 2 + wallOffset
                
                val holeRange = maxOf(heightForHole / 2, 1)
                val holeOffset = if (holeRange > 0) Helper.nextInt(holeRange) * 2 else 0
                val holeY = y1 + 1 + holeOffset
                
                if (wallX > x2 || holeY > y2) return
                
                for (y in y1..y2) {
                    if (y != holeY) {
                        set(wallX, y, Cell.WALL)
                    }
                }
                
                if (wallX > x1 + 1) divide(x1, y1, wallX - 1, y2)
                if (wallX + 1 < x2) divide(wallX + 1, y1, x2, y2)
            } else {
                // Горизонтальная стена
                val wallRange = maxOf(heightForWall / 2, 1)
                val wallOffset = if (wallRange > 0) Helper.nextInt(wallRange) * 2 else 0
                val wallY = y1 + 2 + wallOffset
                
                val holeRange = maxOf(widthForHole / 2, 1)
                val holeOffset = if (holeRange > 0) Helper.nextInt(holeRange) * 2 else 0
                val holeX = x1 + 1 + holeOffset
                
                if (wallY > y2 || holeX > x2) return
                
                for (x in x1..x2) {
                    if (x != holeX) {
                        set(x, wallY, Cell.WALL)
                    }
                }
                
                if (wallY > y1 + 1) divide(x1, y1, x2, wallY - 1)
                if (wallY + 1 < y2) divide(x1, wallY + 1, x2, y2)
            }
        }
        
        private fun isConnectedImpl(startX: Int, startY: Int, goalX: Int, goalY: Int): Boolean {
            if (startX >= width || startY >= height ||
                goalX >= width || goalY >= height) {
                return false
            }
            
            val visited = Array(height) { BooleanArray(width) }
            val queue: Deque<Pair<Int, Int>> = ArrayDeque()
            
            visited[startY][startX] = true
            queue.add(startX to startY)
            
            while (queue.isNotEmpty()) {
                val (x, y) = queue.removeFirst()
                
                if (x == goalX && y == goalY) return true
                
                // Верх
                if (y > 0 && get(x, y - 1) == Cell.PATH && !visited[y - 1][x]) {
                    visited[y - 1][x] = true
                    queue.add(x to y - 1)
                }
                
                // Право
                if (x + 1 < width && get(x + 1, y) == Cell.PATH && !visited[y][x + 1]) {
                    visited[y][x + 1] = true
                    queue.add(x + 1 to y)
                }
                
                // Низ
                if (y + 1 < height && get(x, y + 1) == Cell.PATH && !visited[y + 1][x]) {
                    visited[y + 1][x] = true
                    queue.add(x to y + 1)
                }
                
                // Лево
                if (x > 0 && get(x - 1, y) == Cell.PATH && !visited[y][x - 1]) {
                    visited[y][x - 1] = true
                    queue.add(x - 1 to y)
                }
            }
            
            return false
        }
        
        fun generate() {
            if (width < 5 || height < 5) {
                for (x in 0 until width) {
                    set(x, height / 2, Cell.PATH)
                }
                return
            }
            
            divide(0, 0, width - 1, height - 1)
        }
        
        fun toBoolGrid(): Array<BooleanArray> {
            val result = Array(height) { BooleanArray(width) }
            for (y in 0 until height) {
                for (x in 0 until width) {
                    result[y][x] = (cells[y][x] == Cell.PATH)
                }
            }
            return result
        }
        
        fun isConnected(startX: Int, startY: Int, goalX: Int, goalY: Int): Boolean {
            return isConnectedImpl(startX, startY, goalX, goalY)
        }
        
        companion object {
            fun generateWalkableMaze(width: Int, height: Int): Array<BooleanArray> {
                val maze = Maze(width, height)
                maze.generate()
                
                val startX = 1
                val startY = 1
                val goalX = width - 2
                val goalY = height - 2
                
                if (!maze.isConnected(startX, startY, goalX, goalY)) {
                    for (x in 0 until width) {
                        for (y in 0 until height) {
                            if (x < maze.width && y < maze.height) {
                                if (x == 1 || y == 1 || x == width - 2 || y == height - 2) {
                                    maze.set(x, y, Cell.PATH)
                                }
                            }
                        }
                    }
                }
                
                return maze.toBoolGrid()
            }
        }
    }
    
    private var resultVal: Long = 0L
    private val width = 1001
    private val height = 1001
    
    override fun run() {
        var checksum = 0L
        
        val iters = iterations
        for (i in 0 until iters) {
            val boolGrid = Maze.generateWalkableMaze(width, height)
            
            // Простая checksum для сравнения с C++
            for (y in boolGrid.indices) {
                for (x in boolGrid[y].indices) {
                    if (!boolGrid[y][x]) {
                        checksum += (x * y).toLong()
                    }
                }
            }
        }
        
        resultVal = checksum
    }
    
    override val result: Long
        get() = resultVal
}