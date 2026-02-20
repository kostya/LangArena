package benchmarks

import Benchmark
import java.util.*

class BinarytreesObj : Benchmark() {
    private var n: Long = 0

    init {
        n = configVal("depth")
    }

    class TreeNode(
        val item: Int,
        depth: Int,
    ) {
        val left: TreeNode?
        val right: TreeNode?

        init {
            if (depth > 0) {
                val shift = 1 shl (depth - 1)
                left = TreeNode(item - shift, depth - 1)
                right = TreeNode(item + shift, depth - 1)
            } else {
                left = null
                right = null
            }
        }

        fun sum(): UInt {
            var total = item.toUInt() + 1u
            if (left != null) total += left!!.sum()
            if (right != null) total += right!!.sum()
            return total
        }
    }

    private var resultVal: UInt = 0u

    override fun run(iterationId: Int) {
        val root = TreeNode(0, n.toInt())
        resultVal += root.sum()
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "BinarytreesObj"
}

class BinarytreesArena : Benchmark() {
    private var n: Long = 0

    init {
        n = configVal("depth")
    }

    data class TreeNode(
        val item: Int,
        var left: Int = -1,
        var right: Int = -1,
    )

    class TreeArena {
        private val nodes = ArrayList<TreeNode>()

        fun build(
            item: Int,
            depth: Int,
        ): Int {
            val idx = nodes.size
            nodes.add(TreeNode(item))

            if (depth > 0) {
                val shift = 1 shl (depth - 1)
                val leftIdx = build(item - shift, depth - 1)
                val rightIdx = build(item + shift, depth - 1)
                nodes[idx] = nodes[idx].copy(left = leftIdx, right = rightIdx)
            }

            return idx
        }

        fun sum(idx: Int): UInt {
            val node = nodes[idx]
            var total = node.item.toUInt() + 1u

            if (node.left >= 0) total += sum(node.left)
            if (node.right >= 0) total += sum(node.right)

            return total
        }
    }

    private var resultVal: UInt = 0u

    override fun run(iterationId: Int) {
        val arena = TreeArena()
        val rootIdx = arena.build(0, n.toInt())
        resultVal += arena.sum(rootIdx)
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "BinarytreesArena"
}
