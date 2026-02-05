package benchmarks

import Benchmark
import java.util.*

abstract class GraphPathBenchmark : Benchmark() {
    protected class Graph(val vertices: Int, components: Int = 10) {
        val adj = Array(vertices) { mutableListOf<Int>() }
        private val componentsCount = components

        fun addEdge(u: Int, v: Int) {
            adj[u].add(v)
            adj[v].add(u)
        }

        fun generateRandom() {
            val componentSize = vertices / componentsCount

            for (c in 0 until componentsCount) {
                val startIdx = c * componentSize
                var endIdx = (c + 1) * componentSize
                if (c == componentsCount - 1) {
                    endIdx = vertices
                }

                for (i in startIdx + 1 until endIdx) {
                    val parent = startIdx + Helper.nextInt(i - startIdx)
                    addEdge(i, parent)
                }

                repeat(componentSize * 2) {
                    val u = startIdx + Helper.nextInt(endIdx - startIdx)
                    val v = startIdx + Helper.nextInt(endIdx - startIdx)
                    if (u != v) {
                        addEdge(u, v)
                    }
                }
            }
        }

        fun sameComponent(u: Int, v: Int): Boolean {
            val componentSize = vertices / componentsCount
            return (u / componentSize) == (v / componentSize)
        }
    }

    protected lateinit var graph: Graph
    protected lateinit var pairs: List<Pair<Int, Int>>
    private var resultVal: UInt = 0u
    private var nPairs: Long = 0
    private var vertices: Long = 0

    override fun prepare() {
        if (nPairs == 0L) {
            nPairs = configVal("pairs")
            vertices = configVal("vertices")
            val comps = maxOf(10, (vertices / 10_000).toInt())
            graph = Graph(vertices.toInt(), comps)
            graph.generateRandom()
            pairs = generatePairs(nPairs.toInt())
        }
    }

    private fun generatePairs(n: Int): List<Pair<Int, Int>> {
        val pairs = mutableListOf<Pair<Int, Int>>()
        val componentSize = graph.vertices / 10

        repeat(n) {

            if (Helper.nextInt(100) < 70) {

                val component = Helper.nextInt(10)
                val start = component * componentSize + Helper.nextInt(componentSize)
                var end: Int
                do {
                    end = component * componentSize + Helper.nextInt(componentSize)
                } while (end == start)
                pairs.add(Pair(start, end))
            } else {

                var c1 = Helper.nextInt(10)
                var c2 = Helper.nextInt(10)
                while (c2 == c1) {
                    c2 = Helper.nextInt(10)
                }
                val start = c1 * componentSize + Helper.nextInt(componentSize)
                val end = c2 * componentSize + Helper.nextInt(componentSize)
                pairs.add(Pair(start, end))
            }
        }

        return pairs
    }

    abstract fun test(): Long

    override fun run(iterationId: Int) {
        resultVal += test().toUInt()  
    }

    override fun checksum(): UInt = resultVal
}