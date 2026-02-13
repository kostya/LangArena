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
                val parent = (i - 1) shr 1  
                if (data[i] >= data[parent]) break
                Collections.swap(data, i, parent)
                i = parent
            }
        }

        private fun siftDown(index: Int) {
            var i = index
            val size = data.size
            while (true) {
                val left = (i shl 1) + 1  
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

    private lateinit var gScoresCache: IntArray
    private lateinit var cameFromCache: IntArray  

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

        val size = width * height
        gScoresCache = IntArray(size)
        cameFromCache = IntArray(size)
    }

    private fun distance(aX: Int, aY: Int, bX: Int, bY: Int): Int {
        return abs(aX - bX) + abs(aY - bY)
    }

    private fun packCoords(x: Int, y: Int): Int {
        return y * width + x
    }

    private fun unpackCoords(packed: Int): Pair<Int, Int> {
        return Pair(packed % width, packed / width)
    }

    private fun findPath(): Pair<List<Pair<Int, Int>>?, Int> {
        val grid = mazeGrid

        val gScores = gScoresCache
        val cameFrom = cameFromCache

        gScores.fill(Int.MAX_VALUE)
        cameFrom.fill(-1)

        val openSet = BinaryHeap()
        var nodesExplored = 0

        val startIdx = packCoords(startX, startY)
        gScores[startIdx] = 0
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
                    val idx = packCoords(x, y)
                    val packed = cameFrom[idx]
                    if (packed == -1) break

                    val (px, py) = unpackCoords(packed)
                    x = px
                    y = py
                }

                path.add(startX to startY)
                path.reverse()
                return path to nodesExplored
            }

            val currentIdx = packCoords(current.x, current.y)
            val currentG = gScores[currentIdx]

            for ((dx, dy) in DIRECTIONS) {
                val nx = current.x + dx
                val ny = current.y + dy

                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue
                if (!grid[ny][nx]) continue

                val tentativeG = currentG + STRAIGHT_COST
                val neighborIdx = packCoords(nx, ny)

                if (tentativeG < gScores[neighborIdx]) {

                    cameFrom[neighborIdx] = currentIdx
                    gScores[neighborIdx] = tentativeG

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
        var localResult: UInt = 0u
        localResult = (path?.size ?: 0).toUInt()
        localResult = (localResult shl 5) + nodesExplored.toUInt()
        resultVal += localResult
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "AStarPathfinder"
}