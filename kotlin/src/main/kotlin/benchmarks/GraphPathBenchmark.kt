package benchmarks

import Benchmark
import java.util.*

abstract class GraphPathBenchmark : Benchmark() {
    protected class Graph(val vertices: Int, val jumps: Int = 3, val jumpLen: Int = 100) {
        val adj = Array(vertices) { mutableListOf<Int>() }

        fun addEdge(u: Int, v: Int) {
            adj[u].add(v)
            adj[v].add(u)
        }

        fun generateRandom() {

            for (i in 1 until vertices) {
                addEdge(i, i - 1)
            }

            for (v in 0 until vertices) {
                val numJumps = Helper.nextInt(jumps)
                repeat(numJumps) {
                    val offset = Helper.nextInt(jumpLen) - jumpLen / 2
                    val u = v + offset

                    if (u >= 0 && u < vertices && u != v) {
                        addEdge(v, u)
                    }
                }
            }
        }
    }

    protected lateinit var graph: Graph
    private var resultVal: UInt = 0u

    override fun prepare() {
        val vertices = configVal("vertices").toInt()
        val jumps = configVal("jumps").toInt()
        val jumpLen = configVal("jump_len").toInt()

        graph = Graph(vertices, jumps, jumpLen)
        graph.generateRandom()
    }

    abstract fun test(): Long

    override fun run(iterationId: Int) {
        resultVal += test().toUInt()
    }

    override fun checksum(): UInt = resultVal
}

class GraphPathBFS : GraphPathBenchmark() {
    private fun bfsShortestPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val queue = ArrayDeque<Pair<Int, Int>>()

        visited[start] = true
        queue.add(Pair(start, 0))

        while (queue.isNotEmpty()) {
            val (v, dist) = queue.removeFirst()

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) return dist + 1

                if (!visited[neighbor]) {
                    visited[neighbor] = true
                    queue.add(Pair(neighbor, dist + 1))
                }
            }
        }

        return -1
    }

    override fun test(): Long {
        return bfsShortestPath(0, graph.vertices - 1).toLong()
    }

    override fun name(): String = "GraphPathBFS"
}

class GraphPathDFS : GraphPathBenchmark() {
    private fun dfsFindPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val visited = BooleanArray(graph.vertices)
        val stack = ArrayDeque<IntArray>()
        var bestPath = Int.MAX_VALUE

        stack.add(intArrayOf(start, 0))

        while (stack.isNotEmpty()) {
            val (v, dist) = stack.removeLast()

            if (visited[v] || dist >= bestPath) continue
            visited[v] = true

            for (neighbor in graph.adj[v]) {
                if (neighbor == target) {
                    if (dist + 1 < bestPath) bestPath = dist + 1
                } else if (!visited[neighbor]) {
                    stack.add(intArrayOf(neighbor, dist + 1))
                }
            }
        }

        return if (bestPath == Int.MAX_VALUE) -1 else bestPath
    }

    override fun test(): Long {
        return dfsFindPath(0, graph.vertices - 1).toLong()
    }

    override fun name(): String = "GraphPathDFS"
}

class GraphPathAStar : GraphPathBenchmark() {
    private data class Node(val vertex: Int, val priority: Int) : Comparable<Node> {
        override fun compareTo(other: Node): Int = this.priority.compareTo(other.priority)
    }

    private fun heuristic(v: Int, target: Int): Int = target - v

    private fun aStarShortestPath(start: Int, target: Int): Int {
        if (start == target) return 0

        val gScore = IntArray(graph.vertices) { Int.MAX_VALUE }
        val fScore = IntArray(graph.vertices) { Int.MAX_VALUE }
        val closed = BooleanArray(graph.vertices)

        gScore[start] = 0
        fScore[start] = heuristic(start, target)

        val openSet = PriorityQueue<Node>()
        val inOpenSet = BooleanArray(graph.vertices)

        openSet.add(Node(start, fScore[start]))
        inOpenSet[start] = true

        while (openSet.isNotEmpty()) {
            val current = openSet.poll()
            inOpenSet[current.vertex] = false

            if (current.vertex == target) {
                return gScore[current.vertex]
            }

            closed[current.vertex] = true

            for (neighbor in graph.adj[current.vertex]) {
                if (closed[neighbor]) continue

                val tentativeG = gScore[current.vertex] + 1

                if (tentativeG < gScore[neighbor]) {
                    gScore[neighbor] = tentativeG
                    fScore[neighbor] = tentativeG + heuristic(neighbor, target)

                    if (!inOpenSet[neighbor]) {
                        openSet.add(Node(neighbor, fScore[neighbor]))
                        inOpenSet[neighbor] = true
                    }
                }
            }
        }

        return -1
    }

    override fun test(): Long {
        return aStarShortestPath(0, graph.vertices - 1).toLong()
    }

    override fun name(): String = "GraphPathAStar"
}