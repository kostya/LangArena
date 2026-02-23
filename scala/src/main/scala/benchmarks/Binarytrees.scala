package benchmarks

import scala.collection.mutable.ArrayBuffer

class BinarytreesObj extends Benchmark:
  private val n: Int = configVal("depth").toInt
  private var resultVal: Long = 0L

  override def name(): String = "Binarytrees::Obj"

  class TreeNode(val item: Int, depth: Int):
    val left: TreeNode =
      if depth > 0 then
        val shift = 1 << (depth - 1)
        TreeNode(item - shift, depth - 1)
      else null.asInstanceOf[TreeNode]

    val right: TreeNode =
      if depth > 0 then
        val shift = 1 << (depth - 1)
        TreeNode(item + shift, depth - 1)
      else null.asInstanceOf[TreeNode]

    def sum(): Long =
      var total: Long = item + 1L
      if left != null then total += left.sum()
      if right != null then total += right.sum()
      total

  override def run(iterationId: Int): Unit =
    val root = TreeNode(0, n)
    resultVal = (resultVal + root.sum()) & 0xffffffffL

  override def checksum(): Long = resultVal & 0xffffffffL

class BinarytreesArena extends Benchmark:
  private val n: Int = configVal("depth").toInt
  private var resultVal: Long = 0L

  override def name(): String = "Binarytrees::Arena"

  class TreeNodeArena(val item: Int):
    var left: Int = -1
    var right: Int = -1

  class TreeArena:
    private val nodes = ArrayBuffer.empty[TreeNodeArena]

    def build(item: Int, depth: Int): Int =
      val idx = nodes.length
      nodes += TreeNodeArena(item)

      if depth > 0 then
        val shift = 1 << (depth - 1)
        val leftIdx = build(item - shift, depth - 1)
        val rightIdx = build(item + shift, depth - 1)
        nodes(idx).left = leftIdx
        nodes(idx).right = rightIdx

      idx

    def sum(idx: Int): Long =
      val node = nodes(idx)
      var total = node.item + 1L

      if node.left >= 0 then total += sum(node.left)
      if node.right >= 0 then total += sum(node.right)

      total

  override def run(iterationId: Int): Unit =
    val arena = TreeArena()
    val rootIdx = arena.build(0, n)
    resultVal = (resultVal + arena.sum(rootIdx)) & 0xffffffffL

  override def checksum(): Long = resultVal & 0xffffffffL
