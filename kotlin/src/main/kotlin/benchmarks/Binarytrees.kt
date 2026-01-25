package benchmarks

import Benchmark

class Binarytrees : Benchmark() {
    private var n: Int = 0
    
    init {
        n = iterations
    }
    
    class TreeNode(val item: Int, depth: Int) {
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
        
        fun check(): Int {
            return if (left == null) {
                item
            } else {
                left.check() - right!!.check() + item
            }
        }
        
        companion object {
            fun create(item: Int, depth: Int): TreeNode {
                return TreeNode(item, depth - 1)
            }
        }
    }
    
    private var checkResult: Long = 0L
    
    override fun run() {
        checkResult = 0L
        
        val minDepth = 4
        val maxDepth = Math.max(minDepth + 2, n)
        val stretchDepth = maxDepth + 1
        
        // 1. Stretch tree (только этот!)
        checkResult += TreeNode.create(0, stretchDepth).check().toLong()
        
        // 2. Деревья разных глубин (без long-lived tree!)
        for (depth in minDepth..maxDepth step 2) {
            val iterations = 1 shl (maxDepth - depth + minDepth)
            
            for (i in 1..iterations) {
                checkResult += TreeNode.create(i, depth).check().toLong()
                checkResult += TreeNode.create(-i, depth).check().toLong()
            }
        }
        
        // 3. НЕТ long-lived tree проверки!
        // В Crystal коде её нет!
    }
    
    override val result: Long
        get() = checkResult
}