namespace Benchmarks

open System
open System.Collections.Generic

[<AllowNullLiteral>]
type TreeNodeObj(item: int, depth: int) =
    let left = 
        if depth > 0 then 
            let shift = 1 <<< (depth - 1)
            TreeNodeObj(item - shift, depth - 1)
        else null
    let right = 
        if depth > 0 then 
            let shift = 1 <<< (depth - 1)
            TreeNodeObj(item + shift, depth - 1)
        else null

    member this.Sum() : uint32 =
        let mutable total = uint32 item + 1u
        if not (isNull left) then
            total <- total + left.Sum()
        if not (isNull right) then
            total <- total + right.Sum()
        total

type BinarytreesObj() =
    inherit Benchmark()

    let mutable result = 0u

    override this.Run(_: int64) =
        let n = Helper.Config_i64(this.Name, "depth") |> int
        let root = TreeNodeObj(0, n)
        result <- result + root.Sum()

    override this.Checksum = result

    override this.Prepare() = result <- 0u

type TreeNodeArena =
    struct
        val Item: int
        val mutable Left: int
        val mutable Right: int

        new(item: int) = { Item = item; Left = -1; Right = -1 }
    end

type TreeArena() =
    let nodes = new List<TreeNodeArena>()

    member this.Build(item: int, depth: int) : int =
        let idx = nodes.Count
        nodes.Add(TreeNodeArena(item))

        if depth > 0 then
            let shift = 1 <<< (depth - 1)
            let leftIdx = this.Build(item - shift, depth - 1)
            let rightIdx = this.Build(item + shift, depth - 1)

            let mutable node = nodes.[idx]
            node.Left <- leftIdx
            node.Right <- rightIdx
            nodes.[idx] <- node

        idx

    member this.Sum(idx: int) : uint32 =
        let node = nodes.[idx]
        let mutable total = uint32 node.Item + 1u

        if node.Left >= 0 then
            total <- total + this.Sum(node.Left)
        if node.Right >= 0 then
            total <- total + this.Sum(node.Right)

        total

type BinarytreesArena() =
    inherit Benchmark()

    let mutable result = 0u

    override this.Run(_: int64) =
        let n = Helper.Config_i64(this.Name, "depth") |> int
        let arena = TreeArena()
        let rootIdx = arena.Build(0, n)
        result <- result + arena.Sum(rootIdx)

    override this.Checksum = result

    override this.Prepare() = result <- 0u