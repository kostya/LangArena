import Foundation

final class Binarytrees: BenchmarkProtocol {
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

    func run(iterationId: Int) {
        let minDepth = 4
        let maxDepth = max(minDepth + 2, Int(n))
        let stretchDepth = maxDepth + 1

        resultVal &+= UInt32(bitPattern: Int32(TreeNode.create(item: 0, depth: stretchDepth).check()))

        for depth in stride(from: minDepth, through: maxDepth, by: 2) {
            let iterations = 1 << (maxDepth - depth + minDepth)
            for i in 1...iterations {
                resultVal &+= UInt32(bitPattern: Int32(TreeNode.create(item: i, depth: depth).check()))
                resultVal &+= UInt32(bitPattern: Int32(TreeNode.create(item: -i, depth: depth).check()))
            }
        }
    }

    var checksum: UInt32 {
        return resultVal
    }

    func prepare() {}
}