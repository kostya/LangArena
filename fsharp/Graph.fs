namespace Benchmarks

open System
open System.Collections.Generic

module GraphAlgorithms =
    [<Literal>]
    let INF = Int32.MaxValue / 2

    type Graph(vertices: int, ?components: int) =
        let comps = defaultArg components 10
        let adj = Array.init vertices (fun _ -> ResizeArray<int>())

        member _.Vertices = vertices
        member _.Adj = adj

        member this.AddEdge(u, v) =
            adj.[u].Add(v)
            adj.[v].Add(u)

        member this.GenerateRandom() =
            let componentSize = vertices / comps

            for c = 0 to comps - 1 do
                let startIdx = c * componentSize
                let endIdx = 
                    if c = comps - 1 then vertices 
                    else (c + 1) * componentSize

                for i = startIdx + 1 to endIdx - 1 do
                    let parent = startIdx + Helper.NextInt(i - startIdx)
                    this.AddEdge(i, parent)

                for _ = 1 to componentSize * 2 do
                    let u = startIdx + Helper.NextInt(endIdx - startIdx)
                    let v = startIdx + Helper.NextInt(endIdx - startIdx)
                    if u <> v then this.AddEdge(u, v)

    let generatePairs (graph: Graph) (n: int) =
        let vertices = graph.Vertices
        let componentSize = vertices / 10

        Array.init n (fun _ ->
            if Helper.NextInt(100) < 70 then
                let component = Helper.NextInt(10)
                let start = component * componentSize + Helper.NextInt(componentSize)
                let end' = 
                    let mutable e = component * componentSize + Helper.NextInt(componentSize)
                    while e = start do e <- component * componentSize + Helper.NextInt(componentSize)
                    e
                (start, end')
            else
                let c1 = Helper.NextInt(10)
                let c2 = 
                    let mutable c = Helper.NextInt(10)
                    while c = c1 do c <- Helper.NextInt(10)
                    c
                let start = c1 * componentSize + Helper.NextInt(componentSize)
                let end' = c2 * componentSize + Helper.NextInt(componentSize)
                (start, end'))

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

    module Dijkstra =
        let shortestPath (graph: Graph) start target =
            if start = target then 0
            else
                let dist = Array.create graph.Vertices INF
                let visited = Array.zeroCreate<byte> graph.Vertices

                dist.[start] <- 0
                let maxIterations = graph.Vertices

                let mutable result = -1
                let mutable found = false

                for _ = 0 to maxIterations - 1 do
                    if not found then
                        let mutable u = -1
                        let mutable minDist = INF

                        for v = 0 to graph.Vertices - 1 do
                            if visited.[v] = 0uy && dist.[v] < minDist then
                                minDist <- dist.[v]
                                u <- v

                        if u = -1 || minDist = INF || u = target then
                            if u = target then result <- minDist
                            found <- true
                        else
                            visited.[u] <- 1uy

                            for v in graph.Adj.[u] do
                                if dist.[u] + 1 < dist.[v] then
                                    dist.[v] <- dist.[u] + 1

                result

[<AbstractClass>]
type GraphPathBenchmark() =
    inherit Benchmark()

    let mutable graph: GraphAlgorithms.Graph option = None
    let mutable pairs: (int * int) array = [||]
    let mutable result = 0u
    let mutable nPairs = 0L

    member _.Graph = match graph with Some g -> g | None -> failwith "Graph not initialized"
    member _.Pairs = pairs
    member _.UpdateResult value = result <- result + uint32 value

    override this.Prepare() =
        let vertices = int (this.ConfigVal("vertices"))
        let comps = max 10 (vertices / 10000)

        let g = GraphAlgorithms.Graph(vertices, comps)
        g.GenerateRandom()
        graph <- Some g

        nPairs <- this.ConfigVal("pairs")
        pairs <- GraphAlgorithms.generatePairs g (int nPairs)

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
        let mutable total = 0L

        for (start, end') in this.Pairs do
            let length = GraphAlgorithms.BFS.shortestPath graph start end'
            total <- total + int64 length

        total

type GraphPathDFS() =
    inherit GraphPathBenchmark()

    override this.Test() =
        let graph = this.Graph
        let mutable total = 0L

        for (start, end') in this.Pairs do
            let length = GraphAlgorithms.DFS.findPath graph start end'
            total <- total + int64 length

        total

type GraphPathDijkstra() =
    inherit GraphPathBenchmark()

    override this.Test() =
        let graph = this.Graph
        let mutable total = 0L

        for (start, end') in this.Pairs do
            let length = GraphAlgorithms.Dijkstra.shortestPath graph start end'
            total <- total + int64 length

        total