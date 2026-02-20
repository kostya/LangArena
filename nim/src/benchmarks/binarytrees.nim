import std/math
import ../benchmark

type
  TreeNode = ref object
    left, right: TreeNode
    item: int

proc newTreeNode(item: int, depth: int): TreeNode =
  result = TreeNode(item: item)
  if depth > 0:
    result.left = newTreeNode(2 * item - 1, depth - 1)
    result.right = newTreeNode(2 * item, depth - 1)

proc check(self: TreeNode): int =
  if self.left.isNil or self.right.isNil:
    return self.item
  return self.left.check() - self.right.check() + self.item

type
  Binarytrees* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newBinarytrees(): Benchmark =
  Binarytrees()

method name(self: Binarytrees): string = "Binarytrees"

method prepare(self: Binarytrees) =

  self.n = self.config_val("depth")
  self.resultVal = 0

method run(self: Binarytrees, iteration_id: int) =
  let minDepth = 4
  let maxDepth = max(minDepth + 2, self.n.int)
  let stretchDepth = maxDepth + 1

  let stretchTree = newTreeNode(0, stretchDepth)
  var total: uint32 = uint32(stretchTree.check())

  for depth in countup(minDepth, maxDepth, 2):
    let iterations = 1 shl (maxDepth - depth + minDepth)
    for i in 1..iterations:
      let tree1 = newTreeNode(i, depth)
      let tree2 = newTreeNode(-i, depth)
      total = total + uint32(tree1.check()) + uint32(tree2.check())

  self.resultVal = self.resultVal + total

method checksum(self: Binarytrees): uint32 =
  self.resultVal

registerBenchmark("Binarytrees", newBinarytrees)
