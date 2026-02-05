namespace Benchmarks

open System

[<AllowNullLiteral>]
type TreeNode(item: int, depth: int) =
    let left = 
        if depth > 0 then TreeNode(2 * item - 1, depth - 1)
        else null
    let right = 
        if depth > 0 then TreeNode(2 * item, depth - 1)
        else null

    member this.Check() : int =
        if isNull left || isNull right then
            item
        else
            left.Check() - right.Check() + item

type Binarytrees() =
    inherit Benchmark()

    let mutable result = 0u

    override this.Run(_: int64) =
        let n = Helper.Config_i64("Binarytrees", "depth") |> int
        let minDepth = 4
        let maxDepth = max (minDepth + 2) n
        let stretchDepth = maxDepth + 1

        let stretchTree = TreeNode(0, stretchDepth)
        result <- result + uint32 (stretchTree.Check())

        for depth in minDepth .. 2 .. maxDepth do
            let iterations = 1 <<< (maxDepth - depth + minDepth)
            for i in 1 .. iterations do
                let tree1 = TreeNode(i, depth)
                let tree2 = TreeNode(-i, depth)
                result <- result + uint32 (tree1.Check())
                result <- result + uint32 (tree2.Check())

    override this.Checksum = result

    override this.Prepare() = result <- 0u