namespace Benchmarks

open System
open System.Collections.Generic

module GraphAlgorithms =
    [<Literal>]
    let INF = Int32.MaxValue / 2

    type Graph(vertices: int, ?jumps: int, ?jumpLen: int) =
        let jumpsCount = defaultArg jumps 3
        let jumpLength = defaultArg jumpLen 100
        let adj = Array.init vertices (fun _ -> ResizeArray<int>())

        member _.Vertices = vertices
        member _.Adj = adj
        member _.Jumps = jumpsCount
        member _.JumpLen = jumpLength

        member this.AddEdge(u, v) =
            adj.[u].Add(v)
            adj.[v].Add(u)

        member this.GenerateRandom() =

            for i = 1 to vertices - 1 do
                this.AddEdge(i, i - 1)

            for v = 0 to vertices - 1 do
                let numJumps = Helper.NextInt(jumpsCount)
                for _ = 1 to numJumps do
                    let offset = Helper.NextInt(jumpLength) - jumpLength / 2
                    let u = v + offset
                    if u >= 0 && u < vertices && u <> v then
                        this.AddEdge(v, u)

    module BFS =
        let shortestPath (graph: Graph) start target =
            if start = target then 0
            else
                let visited = Array.zeroCreate<byte> graph.Vertices
                let queue = Queue<int * int>()

                visited.[start] <- 1uy
                queue.Enqueue(start, 0)

                let rec loop () =
                    if queue.Count = 0 then -1
                    else
                        let (v, dist) = queue.Dequeue()

                        let mutable found = false
                        let mutable result = -1

                        for neighbor in graph.Adj.[v] do
                            if not found then
                                if neighbor = target then
                                    found <- true
                                    result <- dist + 1
                                elif visited.[neighbor] = 0uy then
                                    visited.[neighbor] <- 1uy
                                    queue.Enqueue(neighbor, dist + 1)

                        if found then result else loop ()

                loop ()

    module DFS =
        let findPath (graph: Graph) start target =
            if start = target then 0
            else
                let visited = Array.zeroCreate<byte> graph.Vertices
                let stack = Stack<int * int>()
                let mutable bestPath = INF

                stack.Push(start, 0)

                while stack.Count > 0 do
                    let (v, dist) = stack.Pop()

                    if visited.[v] = 0uy && dist < bestPath then
                        visited.[v] <- 1uy

                        for neighbor in graph.Adj.[v] do
                            if neighbor = target then
                                if dist + 1 < bestPath then
                                    bestPath <- dist + 1
                            elif visited.[neighbor] = 0uy then
                                stack.Push(neighbor, dist + 1)

                if bestPath = INF then -1 else bestPath

    module AStar =
        open System.Collections.Generic

        let heuristic (v: int) (target: int) = target - v

        let shortestPath (graph: Graph) start target =
            if start = target then 0
            else
                let gScore = Array.create graph.Vertices INF
                let fScore = Array.create graph.Vertices INF
                let closed = Array.zeroCreate<byte> graph.Vertices

                gScore.[start] <- 0
                fScore.[start] <- heuristic start target

                let openSet = PriorityQueue<int, int>()  
                let inOpenSet = Array.zeroCreate<byte> graph.Vertices

                openSet.Enqueue(start, fScore.[start])
                inOpenSet.[start] <- 1uy

                let mutable result = -1
                let mutable found = false

                while not found && openSet.Count > 0 do

                    let current = openSet.Dequeue()
                    inOpenSet.[current] <- 0uy

                    if current = target then
                        result <- gScore.[current]
                        found <- true
                    else
                        closed.[current] <- 1uy

                        for neighbor in graph.Adj.[current] do
                            if closed.[neighbor] = 0uy then
                                let tentativeG = gScore.[current] + 1

                                if tentativeG < gScore.[neighbor] then
                                    gScore.[neighbor] <- tentativeG
                                    fScore.[neighbor] <- tentativeG + heuristic neighbor target

                                    if inOpenSet.[neighbor] = 0uy then
                                        openSet.Enqueue(neighbor, fScore.[neighbor])
                                        inOpenSet.[neighbor] <- 1uy

                result

[<AbstractClass>]
type GraphPathBenchmark() =
    inherit Benchmark()

    let mutable graph: GraphAlgorithms.Graph option = None
    let mutable result = 0u

    member _.Graph = match graph with Some g -> g | None -> failwith "Graph not initialized"
    member _.UpdateResult value = result <- result + uint32 value

    override this.Prepare() =
        let vertices = int (this.ConfigVal("vertices"))
        let jumps = int (this.ConfigVal("jumps"))
        let jumpLen = int (this.ConfigVal("jump_len"))

        let g = GraphAlgorithms.Graph(vertices, jumps, jumpLen)
        g.GenerateRandom()
        graph <- Some g

        result <- 0u

    override this.Checksum = result

    abstract member Test: unit -> int64

    override this.Run(_: int64) =
        let total = this.Test()
        this.UpdateResult total

type GraphPathBFS() =
    inherit GraphPathBenchmark()

    override this.Test() =
        let graph = this.Graph
        GraphAlgorithms.BFS.shortestPath graph 0 (graph.Vertices - 1) |> int64
    override this.Name = "Graph::BFS"

type GraphPathDFS() =
    inherit GraphPathBenchmark()

    override this.Test() =
        let graph = this.Graph
        GraphAlgorithms.DFS.findPath graph 0 (graph.Vertices - 1) |> int64
    override this.Name = "Graph::DFS"

type GraphPathAStar() =
    inherit GraphPathBenchmark()

    override this.Test() =
        let graph = this.Graph
        GraphAlgorithms.AStar.shortestPath graph 0 (graph.Vertices - 1) |> int64
    override this.Name = "Graph::AStar"