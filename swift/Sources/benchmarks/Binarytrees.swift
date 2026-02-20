import Foundation

final class BinarytreesObj: BenchmarkProtocol {
  private var n: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {
    n = configValue("depth") ?? 0
  }

  final class TreeNode {
    let item: Int
    let left: TreeNode?
    let right: TreeNode?

    init(item: Int, depth: Int) {
      self.item = item
      if depth > 0 {
        let shift = 1 << (depth - 1)
        left = TreeNode(item: item - shift, depth: depth - 1)
        right = TreeNode(item: item + shift, depth: depth - 1)
      } else {
        left = nil
        right = nil
      }
    }

    func sum() -> UInt32 {
      var total = UInt32(bitPattern: Int32(item)) &+ 1
      if let left = left {
        total &+= left.sum()
      }
      if let right = right {
        total &+= right.sum()
      }
      return total
    }
  }

  func run(iterationId: Int) {
    let root = TreeNode(item: 0, depth: Int(n))
    resultVal &+= root.sum()
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}
}

final class BinarytreesArena: BenchmarkProtocol {
  private var n: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {
    n = configValue("depth") ?? 0
  }

  struct TreeNode {
    let item: Int
    var left: Int = -1
    var right: Int = -1
  }

  class TreeArena {
    private var nodes: [TreeNode] = []

    func build(item: Int, depth: Int) -> Int {
      let idx = nodes.count
      nodes.append(TreeNode(item: item))

      if depth > 0 {
        let shift = 1 << (depth - 1)
        let leftIdx = build(item: item - shift, depth: depth - 1)
        let rightIdx = build(item: item + shift, depth: depth - 1)
        nodes[idx].left = leftIdx
        nodes[idx].right = rightIdx
      }

      return idx
    }

    func sum(idx: Int) -> UInt32 {
      let node = nodes[idx]
      var total = UInt32(bitPattern: Int32(node.item)) &+ 1

      if node.left >= 0 {
        total &+= sum(idx: node.left)
      }
      if node.right >= 0 {
        total &+= sum(idx: node.right)
      }

      return total
    }
  }

  func run(iterationId: Int) {
    var arena = TreeArena()
    let rootIdx = arena.build(item: 0, depth: Int(n))
    resultVal &+= arena.sum(idx: rootIdx)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}
}
