package benchmarks

class Binarytrees extends Benchmark:
  private val n: Int = configVal("depth").toInt
  private var resultVal: Long = 0L

  override def name(): String = "Binarytrees"

  class TreeNode(val item: Int, depth: Int):
    val left: TreeNode = 
      if depth > 0 then TreeNode(2 * item - 1, depth - 1)
      else null.asInstanceOf[TreeNode]

    val right: TreeNode = 
      if depth > 0 then TreeNode(2 * item, depth - 1)
      else null.asInstanceOf[TreeNode]

    def check(): Int =
      if left == null then item
      else left.check() - right.check() + item

  object TreeNode:
    def create(item: Int, depth: Int): TreeNode =
      TreeNode(item, depth - 1)

  override def run(iterationId: Int): Unit =
    val minDepth = 4
    val maxDepth = math.max(minDepth + 2, n)
    val stretchDepth = maxDepth + 1

    resultVal += TreeNode.create(0, stretchDepth).check()

    var depth = minDepth
    while depth <= maxDepth do
      val iterations = 1 << (maxDepth - depth + minDepth)
      var i = 1
      while i <= iterations do
        resultVal += TreeNode.create(i, depth).check()
        resultVal += TreeNode.create(-i, depth).check()
        i += 1
      depth += 2

  override def checksum(): Long = resultVal & 0xFFFFFFFFL