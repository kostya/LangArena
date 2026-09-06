package benchmarks

import Benchmark

class BinarytreesObj : Benchmark() {
    private val n = configInt("depth")

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

        fun sum(): UInt = item.toUInt() + 1u + (left?.sum() ?: 0u) + (right?.sum() ?: 0u)
    }

    private var resultVal: UInt = 0u

    override fun run(iterationId: Int) {
        val root = TreeNode(0, n)
        resultVal += root.sum()
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Binarytrees::Obj"
}

class BinarytreesArena : Benchmark() {
    private val n = configInt("depth")

    class TreeNode(
        val item: Int,
    ) {
        var left = -1
        var right = -1
    }

    class TreeArena {
        private val nodes = ArrayList<TreeNode>()

        fun build(
            item: Int,
            depth: Int,
        ): Int {
            val idx = nodes.size
            var node = TreeNode(item)
            nodes.add(node)

            if (depth > 0) {
                val shift = 1 shl (depth - 1)
                node.left = build(item - shift, depth - 1)
                node.right = build(item + shift, depth - 1)
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
        val rootIdx = arena.build(0, n)
        resultVal += arena.sum(rootIdx)
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Binarytrees::Arena"
}
