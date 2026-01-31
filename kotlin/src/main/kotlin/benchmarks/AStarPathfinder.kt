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
    
    private class BinaryHeap(initialCapacity: Int = 64) {
        private val data = ArrayList<Node>(initialCapacity)
        
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
    
    // Кэшированные массивы (выделяются один раз)
    private lateinit var gScoresCache: Array<IntArray>
    private lateinit var cameFromCache: Array<IntArray> // Упакованные координаты: y * width + x
    
    // Статический массив направлений
    private companion object {
        val DIRECTIONS = arrayOf(0 to -1, 1 to 0, 0 to 1, -1 to 0)
        const val STRAIGHT_COST = 1000
        const val MAX_INT = Int.MAX_VALUE
        const val INVALID_COORD = -1
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
    
    // Упаковка координат
    private fun packCoords(x: Int, y: Int): Int = y * width + x
    
    // Распаковка координат
    private fun unpackCoords(packed: Int): Pair<Int, Int> = Pair(packed % width, packed / width)
    
    // Инициализация кэшированных массивов
    private fun initCachedArrays() {
        if (!::gScoresCache.isInitialized || 
            gScoresCache.size != height || 
            gScoresCache[0].size != width) {
            gScoresCache = Array(height) { IntArray(width) }
            cameFromCache = Array(height) { IntArray(width) }
        }
    }
    
    private fun findPathOptimized(): Pair<List<Pair<Int, Int>>?, Int> {
        val grid = mazeGrid
        
        // Используем кэшированные массивы
        val gScores = gScoresCache
        val cameFrom = cameFromCache
        
        // Быстрая инициализация массивов
        for (y in 0 until height) {
            gScores[y].fill(MAX_INT)
            cameFrom[y].fill(INVALID_COORD)
        }
        
        val openSet = BinaryHeap(width * height)
        var nodesExplored = 0
        
        gScores[startY][startX] = 0
        openSet.push(Node(startX, startY, 
                         distance(startX, startY, goalX, goalY)))
        
        while (!openSet.isEmpty()) {
            val current = openSet.pop() ?: break
            nodesExplored++
            
            if (current.x == goalX && current.y == goalY) {
                val path = ArrayList<Pair<Int, Int>>(width * height)
                var x = current.x
                var y = current.y
                
                while (x != startX || y != startY) {
                    path.add(x to y)
                    val packed = cameFrom[y][x]
                    if (packed == INVALID_COORD) break
                    
                    val (prevX, prevY) = unpackCoords(packed)
                    x = prevX
                    y = prevY
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
                    // Упаковываем координаты
                    cameFrom[ny][nx] = packCoords(current.x, current.y)
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
        initCachedArrays()
    }
    
    override fun run(iterationId: Int) {
        val (path, nodesExplored) = findPathOptimized()
        
        var localResult = 0L
        localResult = (localResult shl 5) + (path?.size ?: 0)
        localResult = (localResult shl 5) + nodesExplored
        resultVal = resultVal.plus(localResult.toUInt())  // Эквивалент &+=
    }
    
    override fun checksum(): UInt = resultVal
    
    override fun name(): String = "AStarPathfinder"
}