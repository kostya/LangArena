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
  func name() -> String {
    return "Binarytrees::Obj"
  }
}

final class BinarytreesArena: BenchmarkProtocol {
  private var n: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {
    n = configValue("depth") ?? 0
  }

  struct TreeNode {
    let item: Int32
    var left: Int32 = -1
    var right: Int32 = -1
  }

  private static func build(_ nodes: inout [TreeNode], item: Int32, depth: Int) -> Int32 {
    let idx = Int32(nodes.count)
    nodes.append(TreeNode(item: item))

    if depth > 0 {
      let shift = Int32(1) << (depth - 1)
      let leftIdx = build(&nodes, item: item - shift, depth: depth - 1)
      let rightIdx = build(&nodes, item: item + shift, depth: depth - 1)
      nodes[Int(idx)].left = leftIdx
      nodes[Int(idx)].right = rightIdx
    }

    return idx
  }

  private static func sum(_ nodes: [TreeNode], _ idx: Int32) -> UInt32 {
    let node = nodes[Int(idx)]
    var total = UInt32(bitPattern: node.item) &+ 1

    if node.left >= 0 {
      total &+= sum(nodes, node.left)
    }
    if node.right >= 0 {
      total &+= sum(nodes, node.right)
    }

    return total
  }

  func run(iterationId: Int) {
    var nodes: [TreeNode] = []
    let rootIdx = Self.build(&nodes, item: 0, depth: Int(n))
    resultVal &+= Self.sum(nodes, rootIdx)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}
  func name() -> String {
    return "Binarytrees::Arena"
  }
}
