package benchmarks

import Benchmark

class Binarytrees : Benchmark() {
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
                left = TreeNode(2 * item - 1, depth - 1)
                right = TreeNode(2 * item, depth - 1)
            } else {
                left = null
                right = null
            }
        }

        fun check(): Int =
            if (left == null) {
                item
            } else {
                left.check() - right!!.check() + item
            }

        companion object {
            fun create(
                item: Int,
                depth: Int,
            ): TreeNode = TreeNode(item, depth - 1)
        }
    }

    private var resultVal: UInt = 0u

    override fun run(iterationId: Int) {
        val minDepth = 4
        val maxDepth = Math.max(minDepth + 2, n.toInt())
        val stretchDepth = maxDepth + 1

        resultVal += TreeNode.create(0, stretchDepth).check().toUInt()

        for (depth in minDepth..maxDepth step 2) {
            val iterations = 1 shl (maxDepth - depth + minDepth)

            for (i in 1..iterations) {
                resultVal += TreeNode.create(i, depth).check().toUInt()
                resultVal += TreeNode.create(-i, depth).check().toUInt()
            }
        }
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Binarytrees"
}
