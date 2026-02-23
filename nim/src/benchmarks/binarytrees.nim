import std/math
import ../benchmark

type
  TreeNodeObj = ref object
    left, right: TreeNodeObj
    item: int

proc newTreeNodeObj(item: int, depth: int): TreeNodeObj =
  result = TreeNodeObj(item: item)
  if depth > 0:
    let shift = 1 shl (depth - 1)
    result.left = newTreeNodeObj(item - shift, depth - 1)
    result.right = newTreeNodeObj(item + shift, depth - 1)

proc sum(self: TreeNodeObj): uint32 =
  var total = uint32(self.item) + 1'u32
  if not self.left.isNil:
    total += self.left.sum()
  if not self.right.isNil:
    total += self.right.sum()
  return total

type
  BinarytreesObj* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newBinarytreesObj(): Benchmark =
  BinarytreesObj()

method name(self: BinarytreesObj): string = "Binarytrees::Obj"

method prepare(self: BinarytreesObj) =
  self.n = self.config_val("depth")
  self.resultVal = 0

method run(self: BinarytreesObj, iteration_id: int) =
  let tree = newTreeNodeObj(0, self.n.int)
  self.resultVal += tree.sum()

method checksum(self: BinarytreesObj): uint32 =
  self.resultVal

registerBenchmark("Binarytrees::Obj", newBinarytreesObj)

type
  TreeNodeArena = object
    item: int
    left: int
    right: int

  TreeArena = object
    nodes: seq[TreeNodeArena]

proc initTreeArena(): TreeArena =
  result.nodes = newSeq[TreeNodeArena]()

proc build(self: var TreeArena, item: int, depth: int): int =
  let idx = self.nodes.len
  self.nodes.add(TreeNodeArena(item: item, left: -1, right: -1))

  if depth > 0:
    let shift = 1 shl (depth - 1)
    let leftIdx = self.build(item - shift, depth - 1)
    let rightIdx = self.build(item + shift, depth - 1)
    self.nodes[idx].left = leftIdx
    self.nodes[idx].right = rightIdx

  return idx

proc sum(self: TreeArena, idx: int): uint32 =
  let node = self.nodes[idx]
  var total = uint32(node.item) + 1'u32

  if node.left >= 0:
    total += self.sum(node.left)
  if node.right >= 0:
    total += self.sum(node.right)

  return total

type
  BinarytreesArena* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newBinarytreesArena(): Benchmark =
  result = BinarytreesArena()

method name(self: BinarytreesArena): string = "Binarytrees::Arena"

method prepare(self: BinarytreesArena) =
  self.n = self.config_val("depth")
  self.resultVal = 0

method run(self: BinarytreesArena, iteration_id: int) =
  var arena = initTreeArena()
  let rootIdx = arena.build(0, self.n.int)
  self.resultVal += arena.sum(rootIdx)

method checksum(self: BinarytreesArena): uint32 =
  self.resultVal

registerBenchmark("Binarytrees::Arena", newBinarytreesArena)
