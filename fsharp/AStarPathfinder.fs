namespace Benchmarks

open System
open System.Collections.Generic

[<Struct; CustomComparison; CustomEquality>]
type ANode =
    val X: int
    val Y: int
    val FScore: int

    new(x, y, fScore) = { X = x; Y = y; FScore = fScore }

    interface IComparable with
        member this.CompareTo(other: obj) =
            if other :? ANode then
                let otherANode = other :?> ANode
                if this.FScore <> otherANode.FScore then
                    this.FScore.CompareTo(otherANode.FScore)
                elif this.Y <> otherANode.Y then
                    this.Y.CompareTo(otherANode.Y)
                else
                    this.X.CompareTo(otherANode.X)
            else
                1

    interface IComparable<ANode> with
        member this.CompareTo(other) =
            if this.FScore <> other.FScore then
                this.FScore.CompareTo(other.FScore)
            elif this.Y <> other.Y then
                this.Y.CompareTo(other.Y)
            else
                this.X.CompareTo(other.X)

    override this.Equals(other: obj) =
        match other with
        | :? ANode as otherANode ->
            this.X = otherANode.X && this.Y = otherANode.Y && this.FScore = otherANode.FScore
        | _ -> false

    override this.GetHashCode() =
        HashCode.Combine(this.X, this.Y, this.FScore)

    interface IEquatable<ANode> with
        member this.Equals(other) =
            this.X = other.X && this.Y = other.Y && this.FScore = other.FScore

type BinaryHeap(initialCapacity: int) =
    let mutable data = Array.zeroCreate<ANode> initialCapacity
    let mutable count = 0

    let ensureCapacity () =
        if count >= data.Length then
            Array.Resize(&data, data.Length * 2)

    let swap i j =
        let temp = data.[i]
        data.[i] <- data.[j]
        data.[j] <- temp

    let siftUp index =
        let mutable idx = index
        let nodes = data

        while idx > 0 do
            let parent = (idx - 1) >>> 1
            if nodes.[idx].FScore >= nodes.[parent].FScore then
                idx <- 0  
            else
                swap idx parent
                idx <- parent

    let siftDown index =
        let mutable idx = index
        let nodes = data
        let size = count
        let mutable continueLoop = true

        while continueLoop do
            let left = (idx <<< 1) + 1
            let right = left + 1
            let mutable smallest = idx

            if left < size && nodes.[left].FScore < nodes.[smallest].FScore then
                smallest <- left

            if right < size && nodes.[right].FScore < nodes.[smallest].FScore then
                smallest <- right

            if smallest = idx then
                continueLoop <- false
            else
                swap idx smallest
                idx <- smallest

    member this.Push(item: ANode) =
        ensureCapacity()
        data.[count] <- item
        count <- count + 1
        siftUp(count - 1)

    member this.Pop() =
        if count = 0 then None
        else
            let result = data.[0]
            count <- count - 1

            if count > 0 then
                data.[0] <- data.[count]
                siftDown(0)

            Some result

    member _.IsEmpty() = count = 0

type AStarPathfinder() =
    inherit Benchmark()

    [<Literal>]
    let STRAIGHT_COST = 1000

    let directions = [| struct (0, -1); struct (1, 0); struct (0, 1); struct (-1, 0) |]

    let mutable width = 0
    let mutable height = 0
    let mutable startX = 1
    let mutable startY = 1
    let mutable goalX = 0
    let mutable goalY = 0
    let mutable mazeGrid = Array2D.zeroCreate<bool> 0 0
    let mutable gScoresCache = Array.empty<int>
    let mutable cameFromCache = Array.empty<int>
    let mutable result = 0u

    let distance aX aY bX bY =
        abs (aX - bX) + abs (aY - bY)

    let packCoords x y width = y * width + x

    let unpackCoords packed width = 
        (packed % width, packed / width)

    let fillArray (arr: 'T[]) (value: 'T) =
        for i = 0 to arr.Length - 1 do
            arr.[i] <- value

    let findPath () =
        let grid = mazeGrid
        let w = width
        let h = height
        let gScores = gScoresCache
        let cameFrom = cameFromCache

        fillArray gScores Int32.MaxValue
        fillArray cameFrom -1

        let openSet = BinaryHeap(w * h)
        let mutable nodesExplored = 0

        let startIdx = packCoords startX startY w
        gScores.[startIdx] <- 0
        openSet.Push(ANode(startX, startY, distance startX startY goalX goalY))

        let mutable foundPath: (int * int) list option = None

        while not (openSet.IsEmpty()) && foundPath.IsNone do
            match openSet.Pop() with
            | Some current ->
                nodesExplored <- nodesExplored + 1

                if current.X = goalX && current.Y = goalY then
                    let path = ResizeArray<int * int>()
                    let mutable x = current.X
                    let mutable y = current.Y

                    while x <> startX || y <> startY do
                        path.Add((x, y))
                        let idx = packCoords x y w
                        let packed = cameFrom.[idx]

                        if packed = -1 then
                            x <- startX
                            y <- startY
                        else
                            let (prevX, prevY) = unpackCoords packed w
                            x <- prevX
                            y <- prevY

                    path.Add((startX, startY))
                    let reversed = List.ofSeq path
                    foundPath <- Some (List.rev reversed)
                else
                    let currentIdx = packCoords current.X current.Y w
                    let currentG = gScores.[currentIdx]

                    for i = 0 to directions.Length - 1 do
                        let struct (dx, dy) = directions.[i]
                        let nx = current.X + dx
                        let ny = current.Y + dy

                        if nx >= 0 && nx < w && ny >= 0 && ny < h && grid.[ny, nx] then
                            let tentativeG = currentG + STRAIGHT_COST
                            let neighborIdx = packCoords nx ny w

                            if tentativeG < gScores.[neighborIdx] then
                                cameFrom.[neighborIdx] <- currentIdx
                                gScores.[neighborIdx] <- tentativeG

                                let fScore = tentativeG + distance nx ny goalX goalY
                                openSet.Push(ANode(nx, ny, fScore))
            | None -> ()

        match foundPath with
        | Some path -> (Some path, nodesExplored)
        | None -> (None, nodesExplored)

    override this.Checksum = result

    override this.Prepare() =
        width <- int (this.ConfigVal("w"))
        height <- int (this.ConfigVal("h"))
        startX <- 1
        startY <- 1
        goalX <- width - 2
        goalY <- height - 2

        let size = width * height
        gScoresCache <- Array.zeroCreate size
        cameFromCache <- Array.zeroCreate size

        mazeGrid <- MazeTypes.Maze.GenerateWalkableMaze(width, height)
        result <- 0u

    override this.Run(_: int64) =
        let (path, nodesExplored) = findPath()

        let mutable localResult = 0u
        localResult <- uint32 (match path with Some p -> p.Length | None -> 0)
        localResult <- (localResult <<< 5) + uint32 nodesExplored
        result <- result + localResult