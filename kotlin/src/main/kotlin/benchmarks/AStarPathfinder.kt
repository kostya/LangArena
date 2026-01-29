package benchmarks

import Benchmark
import java.util.*
import kotlin.math.*

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
    
    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
        startX = 1
        startY = 1
        goalX = width - 2
        goalY = height - 2
    }
    
    private fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
        return (abs(aX - bX) + abs(aY - bY))
    }
    
    private fun findPath(): Pair<kotlin.collections.List<Pair<Int, Int>>?, Int> {
        val grid = mazeGrid
        
        val gScores = Array(height) { IntArray(width) { Int.MAX_VALUE } }
        val cameFrom = Array(height) { Array<Pair<Int, Int>?>(width) { null } }
        val openSet = BinaryHeap()
        var nodesExplored = 0
        
        gScores[startY][startX] = 0
        openSet.push(Node(startX, startY, 
                         distance(startX, startY, goalX, goalY)))
        
        val directions = listOf(0 to -1, 1 to 0, 0 to 1, -1 to 0)
        
        while (!openSet.isEmpty()) {
            val current = openSet.pop() ?: break
            nodesExplored++
            
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
                return path to nodesExplored
            }
            
            val currentG = gScores[current.y][current.x]
            
            for ((dx, dy) in directions) {
                val nx = current.x + dx
                val ny = current.y + dy
                
                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue
                if (!grid[ny][nx]) continue
                
                val tentativeG = currentG + 1000
                
                if (tentativeG < gScores[ny][nx]) {
                    cameFrom[ny][nx] = current.x to current.y
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
    }
    
    override fun run(iterationId: Int) {
        val (path, nodesExplored) = findPath()
        
        var localResult = 0L
        localResult = (localResult shl 5) + (path?.size ?: 0)
        localResult = (localResult shl 5) + nodesExplored
        resultVal += localResult.toUInt()  // &+= эквивалент
    }
    
    override fun checksum(): UInt = resultVal
    
    override fun name(): String = "AStarPathfinder"
}