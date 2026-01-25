import Foundation
final class Binarytrees: BenchmarkProtocol {
    private var n: Int = 0
    private var checkResult: Int64 = 0
    init() {
        n = iterations
    }
    final class TreeNode {
        let item: Int
        let left: TreeNode?
        let right: TreeNode?
        init(item: Int, depth: Int) {
            self.item = item
            if depth > 0 {
                left = TreeNode(item: 2 * item - 1, depth: depth - 1)
                right = TreeNode(item: 2 * item, depth: depth - 1)
            } else {
                left = nil
                right = nil
            }
        }
        func check() -> Int {
            if let left = left, let right = right {
                return left.check() - right.check() + item
            } else {
                return item
            }
        }
        static func create(item: Int, depth: Int) -> TreeNode {
            return TreeNode(item: item, depth: depth - 1)
        }
    }
    func run() {
        checkResult = 0
        let minDepth = 4
        let maxDepth = max(minDepth + 2, n)
        let stretchDepth = maxDepth + 1
        // 1. Stretch tree
        checkResult += Int64(TreeNode.create(item: 0, depth: stretchDepth).check())
        // 2. Деревья разных глубин
        for depth in stride(from: minDepth, through: maxDepth, by: 2) {
            let iterations = 1 << (maxDepth - depth + minDepth)
            for i in 1...iterations {
                checkResult += Int64(TreeNode.create(item: i, depth: depth).check())
                checkResult += Int64(TreeNode.create(item: -i, depth: depth).check())
            }
        }
    }
    var result: Int64 {
        return checkResult
    }
    func prepare() {}
}