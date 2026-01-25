package benchmarks

import Benchmark
import java.util.*
import kotlin.math.*

class AStarPathfinder : Benchmark() {
    private interface Heuristic {
        fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int
    }
    
    private class ManhattanHeuristic : Heuristic {
        override fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
            return (abs(aX - bX) + abs(aY - bY)) * 1000
        }
    }
    
    private class EuclideanHeuristic : Heuristic {
        override fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
            val dx = abs(aX - bX).toDouble()
            val dy = abs(aY - bY).toDouble()
            return (sqrt(dx * dx + dy * dy) * 1000.0).toInt()
        }
    }
    
    private class ChebyshevHeuristic : Heuristic {
        override fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
            return maxOf(abs(aX - bX), abs(aY - bY)) * 1000
        }
    }
    
    private data class Node(val x: Int, val y: Int, val fScore: Int) : Comparable<Node> {
        override fun compareTo(other: Node): Int {
            // Сортировка по fScore, затем по координатам для стабильности
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
    
    private var resultVal: Long = 0L
    private val startX: Int
    private val startY: Int
    private val goalX: Int
    private val goalY: Int
    private val width: Int
    private val height: Int
    private var mazeGrid: Array<BooleanArray>? = null
    
    init {
        width = iterations
        height = iterations
        startX = 1
        startY = 1
        goalX = width - 2
        goalY = height - 2
    }
    
    private fun generateWalkableMaze(width: Int, height: Int): Array<BooleanArray> {
        return MazeGenerator.Maze.generateWalkableMaze(width, height)
    }
    
    private fun ensureMazeGrid(): Array<BooleanArray> {
        if (mazeGrid == null) {
            mazeGrid = generateWalkableMaze(width, height)
        }
        return mazeGrid!!
    }
    
    private fun findPath(heuristic: Heuristic, allowDiagonal: Boolean = false): List<Pair<Int, Int>>? {
        val grid = ensureMazeGrid()
        
        val gScores = Array(height) { IntArray(width) { Int.MAX_VALUE } }
        val cameFrom = Array(height) { Array<Pair<Int, Int>?>(width) { null } }
        val openSet = BinaryHeap()
        
        gScores[startY][startX] = 0
        openSet.push(Node(startX, startY, 
                         heuristic.distance(startX, startY, goalX, goalY)))
        
        val directions = if (allowDiagonal) {
            listOf(
                0 to -1, 1 to 0, 0 to 1, -1 to 0,
                -1 to -1, 1 to -1, 1 to 1, -1 to 1
            )
        } else {
            listOf(0 to -1, 1 to 0, 0 to 1, -1 to 0)
        }
        
        val diagonalCost = if (allowDiagonal) 1414 else 1000
        
        while (!openSet.isEmpty()) {
            val current = openSet.pop() ?: break
            
            if (current.x == goalX && current.y == goalY) {
                val path = mutableListOf<Pair<Int, Int>>()
                var x = current.x
                var y = current.y
                
                while (x != startX || y != startY) {
                    path.add(x to y)
                    val (prevX, prevY) = cameFrom[y][x]!!
                    x = prevX
                    y = prevY
                }
                
                path.add(startX to startY)
                path.reverse()
                return path
            }
            
            val currentG = gScores[current.y][current.x]
            
            for ((dx, dy) in directions) {
                val nx = current.x + dx
                val ny = current.y + dy
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue
                if (!grid[ny][nx]) continue
                
                val moveCost = if (abs(dx) == 1 && abs(dy) == 1) diagonalCost else 1000
                val tentativeG = currentG + moveCost
                
                if (tentativeG < gScores[ny][nx]) {
                    cameFrom[ny][nx] = current.x to current.y
                    gScores[ny][nx] = tentativeG
                    
                    val fScore = tentativeG + heuristic.distance(nx, ny, goalX, goalY)
                    openSet.push(Node(nx, ny, fScore))
                }
            }
        }
        
        return null
    }
    
    private fun estimateNodesExplored(heuristic: Heuristic, allowDiagonal: Boolean = false): Int {
        val grid = ensureMazeGrid()
        
        val gScores = Array(height) { IntArray(width) { Int.MAX_VALUE } }
        val openSet = BinaryHeap()
        val closed = Array(height) { BooleanArray(width) }
        
        gScores[startY][startX] = 0
        openSet.push(Node(startX, startY, 
                         heuristic.distance(startX, startY, goalX, goalY)))
        
        val directions = if (allowDiagonal) {
            listOf(
                0 to -1, 1 to 0, 0 to 1, -1 to 0,
                -1 to -1, 1 to -1, 1 to 1, -1 to 1
            )
        } else {
            listOf(0 to -1, 1 to 0, 0 to 1, -1 to 0)
        }
        
        var nodesExplored = 0
        
        while (!openSet.isEmpty()) {
            val current = openSet.pop() ?: break
            
            if (current.x == goalX && current.y == goalY) {
                break
            }
            
            if (closed[current.y][current.x]) continue
            
            closed[current.y][current.x] = true
            nodesExplored++
            
            val currentG = gScores[current.y][current.x]
            
            for ((dx, dy) in directions) {
                val nx = current.x + dx
                val ny = current.y + dy
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue
                if (!grid[ny][nx]) continue
                
                val moveCost = if (abs(dx) == 1 && abs(dy) == 1) 1414 else 1000
                val tentativeG = currentG + moveCost
                
                if (tentativeG < gScores[ny][nx]) {
                    gScores[ny][nx] = tentativeG
                    
                    val fScore = tentativeG + heuristic.distance(nx, ny, goalX, goalY)
                    openSet.push(Node(nx, ny, fScore))
                }
            }
        }
        
        return nodesExplored
    }
    
    private fun benchmarkDifferentApproaches(): Triple<Int, Int, Int> {
        val heuristics = listOf(
            ManhattanHeuristic(),
            EuclideanHeuristic(),
            ChebyshevHeuristic()
        )
        
        var totalPathsFound = 0
        var totalPathLength = 0
        var totalNodesExplored = 0
        
        for (heuristic in heuristics) {
            val path = findPath(heuristic, false)
            if (path != null) {
                totalPathsFound++
                totalPathLength += path.size
                totalNodesExplored += estimateNodesExplored(heuristic, false)
            }
        }
        
        return Triple(totalPathsFound, totalPathLength, totalNodesExplored)
    }
    
    override fun prepare() {
        ensureMazeGrid()
    }
    
    override fun run() {
        var totalPathsFound = 0
        var totalPathLength = 0
        var totalNodesExplored = 0
        
        val iters = 10
        for (i in 0 until iters) {
            val (pathsFound, pathLength, nodesExplored) = benchmarkDifferentApproaches()
            
            totalPathsFound += pathsFound
            totalPathLength += pathLength
            totalNodesExplored += nodesExplored
        }
        
        val pathsChecksum = Helper.checksumF64(totalPathsFound.toDouble())
        val lengthChecksum = Helper.checksumF64(totalPathLength.toDouble())
        val nodesChecksum = Helper.checksumF64(totalNodesExplored.toDouble())

        resultVal = (pathsChecksum).toLong() xor
                   ((lengthChecksum).toLong() shl 16) xor
                   ((nodesChecksum).toLong() shl 32)
    }
    
    override val result: Long
        get() = resultVal
}