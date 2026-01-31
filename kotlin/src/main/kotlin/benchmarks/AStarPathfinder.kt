package benchmarks

import Benchmark
import kotlin.math.abs
import java.util.Collections

class AStarPathfinder : Benchmark() {
    private data class Node(val x: Int, val y: Int, val fScore: Int) : Comparable<Node> {
        override fun compareTo(other: Node): Int {
            if (fScore != other.fScore) {
                return fScore.compareTo(other.fScore)
            }
            if (y != other.y) {
                return y.compareTo(other.y)
            }
            return x.compareTo(other.x)
        }
    }
    
    private class BinaryHeap {
        private val data = mutableListOf<Node>()
        
        fun push(item: Node) {
            data.add(item)
            siftUp(data.size - 1)
        }
        
        fun pop(): Node? {
            if (data.isEmpty()) {
                return null
            }
            
            if (data.size == 1) {
                return data.removeAt(0)
            }
            
            val result = data[0]
            data[0] = data[data.size - 1]
            data.removeAt(data.size - 1)
            siftDown(0)
            return result
        }
        
        fun isEmpty(): Boolean = data.isEmpty()
        
        private fun siftUp(index: Int) {
            var i = index
            while (i > 0) {
                val parent = (i - 1) / 2
                if (data[i] >= data[parent]) break
                Collections.swap(data, i, parent)
                i = parent
            }
        }
        
        private fun siftDown(index: Int) {
            var i = index
            val size = data.size
            while (true) {
                val left = i * 2 + 1
                val right = left + 1
                var smallest = i
                
                if (left < size && data[left] < data[smallest]) {
                    smallest = left
                }
                
                if (right < size && data[right] < data[smallest]) {
                    smallest = right
                }
                
                if (smallest == i) break
                
                Collections.swap(data, i, smallest)
                i = smallest
            }
        }
    }
    
    private var resultVal: UInt = 0u
    private val startX: Int
    private val startY: Int
    private val goalX: Int
    private val goalY: Int
    private val width: Int
    private val height: Int
    private lateinit var mazeGrid: Array<BooleanArray>
    
    // Кэшированные массивы
    private lateinit var gScoresCache: Array<IntArray>
    private lateinit var cameFromCache: Array<Array<Point?>>
    
    private data class Point(var x: Int, var y: Int)
    
    // Статические константы
    private companion object {
        val DIRECTIONS = arrayOf(0 to -1, 1 to 0, 0 to 1, -1 to 0)
        const val STRAIGHT_COST = 1000
    }
    
    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
        startX = 1
        startY = 1
        goalX = width - 2
        goalY = height - 2
    }
    
    private fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
        return abs(aX - bX) + abs(aY - bY)
    }
    
    private fun findPath(): Pair<List<Pair<Int, Int>>?, Int> {
        val grid = mazeGrid
        
        // Используем кэшированные массивы
        val gScores = gScoresCache
        val cameFrom = cameFromCache
        
        // Быстрая инициализация gScores
        if (height > 0 && width > 0) {
            val firstRow = gScores[0]
            firstRow.fill(Int.MAX_VALUE)
            for (y in 1 until height) {
                System.arraycopy(firstRow, 0, gScores[y], 0, width)
            }
        }
        
        // Инициализация cameFrom
        for (y in 0 until height) {
            val row = cameFrom[y]
            for (x in 0 until width) {
                row[x] = null
            }
        }
        
        val openSet = BinaryHeap()
        var nodesExplored = 0
        
        gScores[startY][startX] = 0
        openSet.push(Node(startX, startY, 
                         distance(startX, startY, goalX, goalY)))
        
        while (!openSet.isEmpty()) {
            val current = openSet.pop() ?: break
            nodesExplored++
            
            if (current.x == goalX && current.y == goalY) {
                val path = mutableListOf<Pair<Int, Int>>()
                var x = current.x
                var y = current.y
                
                while (x != startX || y != startY) {
                    path.add(x to y)
                    val prev = cameFrom[y][x]
                    if (prev == null) break
                    x = prev.x
                    y = prev.y
                }
                
                path.add(startX to startY)
                path.reverse()
                return path to nodesExplored
            }
            
            val currentG = gScores[current.y][current.x]
            
            for ((dx, dy) in DIRECTIONS) {
                val nx = current.x + dx
                val ny = current.y + dy
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue
                if (!grid[ny][nx]) continue
                
                val tentativeG = currentG + STRAIGHT_COST
                
                if (tentativeG < gScores[ny][nx]) {
                    // Обновляем существующий Point объект или создаем новый
                    val point = cameFrom[ny][nx]
                    if (point == null) {
                        cameFrom[ny][nx] = Point(current.x, current.y)
                    } else {
                        point.x = current.x
                        point.y = current.y
                    }
                    gScores[ny][nx] = tentativeG
                    
                    val fScore = tentativeG + distance(nx, ny, goalX, goalY)
                    openSet.push(Node(nx, ny, fScore))
                }
            }
        }
        
        return null to nodesExplored
    }
    
    override fun prepare() {
        mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width, height)
        
        // Инициализируем кэшированные массивы один раз
        if (!::gScoresCache.isInitialized || 
            gScoresCache.size != height || 
            gScoresCache[0].size != width) {
            gScoresCache = Array(height) { IntArray(width) }
            cameFromCache = Array(height) { arrayOfNulls<Point>(width) }
            
            // Предварительно создаем Point объекты
            for (y in 0 until height) {
                for (x in 0 until width) {
                    cameFromCache[y][x] = Point(-1, -1)
                }
            }
        }
    }
    
    override fun run(iterationId: Int) {
        val (path, nodesExplored) = findPath()
        
        var localResult = 0L
        localResult = (localResult shl 5) + (path?.size ?: 0)
        localResult = (localResult shl 5) + nodesExplored
        resultVal = resultVal.plus(localResult.toUInt())
    }
    
    override fun checksum(): UInt = resultVal
    
    override fun name(): String = "AStarPathfinder"
}