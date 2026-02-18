namespace Benchmarks

open System
open System.Collections.Generic

module MazeTypes =
    type CellKind =
        | Wall = 0
        | Space = 1
        | Start = 2
        | Finish = 3
        | Border = 4
        | Path = 5

    type Cell(x: int, y: int) =
        let mutable kind = CellKind.Wall
        let neighbors = ResizeArray<Cell>(4)  

        member _.X = x
        member _.Y = y
        member _.Kind with get() = kind and set(value) = kind <- value
        member _.Neighbors = neighbors

        member this.AddNeighbor(cell: Cell) =
            neighbors.Add(cell)

        member this.IsWalkable() =
            kind = CellKind.Space || kind = CellKind.Start || kind = CellKind.Finish

        member this.Reset() =
            if kind = CellKind.Space then
                kind <- CellKind.Wall

    type Maze(width: int, height: int) as this =
        let w = max width 5
        let h = max height 5
        let cells = Array2D.init h w (fun y x -> Cell(x, y))
        let start = cells.[1, 1]
        let finish = cells.[h-2, w-2]

        do
            start.Kind <- CellKind.Start
            finish.Kind <- CellKind.Finish
            this.UpdateNeighbors()

        member _.Width = w
        member _.Height = h
        member _.Cells = cells
        member _.Start = start
        member _.Finish = finish

        member this.UpdateNeighbors() =
            for y = 0 to h - 1 do
                for x = 0 to w - 1 do
                    cells.[y, x].Neighbors.Clear()

            for y = 0 to h - 1 do
                for x = 0 to w - 1 do
                    let cell = cells.[y, x]

                    if x > 0 && y > 0 && x < w - 1 && y < h - 1 then
                        cell.AddNeighbor(cells.[y-1, x])
                        cell.AddNeighbor(cells.[y+1, x])
                        cell.AddNeighbor(cells.[y, x+1])
                        cell.AddNeighbor(cells.[y, x-1])

                        for _ = 1 to 4 do
                            let i = Helper.NextInt(4)
                            let j = Helper.NextInt(4)
                            if i <> j then
                                let temp = cell.Neighbors.[i]
                                cell.Neighbors.[i] <- cell.Neighbors.[j]
                                cell.Neighbors.[j] <- temp
                    else
                        cell.Kind <- CellKind.Border

        member this.Reset() =
            for y = 0 to h - 1 do
                for x = 0 to w - 1 do
                    cells.[y, x].Reset()
            start.Kind <- CellKind.Start
            finish.Kind <- CellKind.Finish

        member this.Dig(startCell: Cell) =
            let stack = Stack<Cell>()
            stack.Push(startCell)

            while stack.Count > 0 do
                let cell = stack.Pop()

                let mutable walkable = 0
                for i = 0 to cell.Neighbors.Count - 1 do
                    if cell.Neighbors.[i].IsWalkable() then
                        walkable <- walkable + 1

                if walkable = 1 then
                    cell.Kind <- CellKind.Space

                    for i = 0 to cell.Neighbors.Count - 1 do
                        if cell.Neighbors.[i].Kind = CellKind.Wall then
                            stack.Push(cell.Neighbors.[i])

        member this.EnsureOpenFinish(startCell: Cell) =
            let stack = Stack<Cell>()
            stack.Push(startCell)

            while stack.Count > 0 do
                let cell = stack.Pop()

                cell.Kind <- CellKind.Space

                let mutable walkable = 0
                for i = 0 to cell.Neighbors.Count - 1 do
                    if cell.Neighbors.[i].IsWalkable() then
                        walkable <- walkable + 1

                if walkable <= 1 then
                    for i = 0 to cell.Neighbors.Count - 1 do
                        if cell.Neighbors.[i].Kind = CellKind.Wall then
                            stack.Push(cell.Neighbors.[i])

        member this.Generate() =
            for n in start.Neighbors do
                if n.Kind = CellKind.Wall then
                    this.Dig(n)

            for n in finish.Neighbors do
                if n.Kind = CellKind.Wall then
                    this.EnsureOpenFinish(n)

        member this.MiddleCell() =
            cells.[h / 2, w / 2]

        member this.Checksum() =
            let mutable hasher = 2166136261u
            let prime = 16777619u

            for y = 0 to h - 1 do
                for x = 0 to w - 1 do
                    let cell = cells.[y, x]
                    if cell.Kind = CellKind.Space then
                        let val' = uint32 (x * y)
                        hasher <- (hasher ^^^ val') * prime
            hasher

        member this.PrintToConsole() =
            for y = 0 to h - 1 do
                for x = 0 to w - 1 do
                    match cells.[y, x].Kind with
                    | CellKind.Space -> printf " "
                    | CellKind.Wall -> printf "\u001B[34m#\u001B[0m"
                    | CellKind.Border -> printf "\u001B[31mO\u001B[0m"
                    | CellKind.Start -> printf "\u001B[32m>\u001B[0m"
                    | CellKind.Finish -> printf "\u001B[32m<\u001B[0m"
                    | CellKind.Path -> printf "\u001B[33m.\u001B[0m"
                    | _ -> printf "?"
                printfn ""
            printfn ""

type BfsPathNode(cell: MazeTypes.Cell, parent: int) =
    member _.Cell = cell
    member _.Parent = parent

type MazeGenerator() =
    inherit Benchmark()

    let mutable width = 0
    let mutable height = 0
    let mutable maze : MazeTypes.Maze option = None
    let mutable resultVal = 0u

    override this.Prepare() =
        width <- int (this.ConfigVal("w"))
        height <- int (this.ConfigVal("h"))
        let newMaze = MazeTypes.Maze(width, height)
        maze <- Some newMaze
        resultVal <- 0u

    override this.Run(_: int64) =
        match maze with
        | Some m ->
            m.Reset()
            m.Generate()
            resultVal <- resultVal + uint32 (m.MiddleCell().Kind)
        | None -> ()

    override this.Checksum =
        match maze with
        | Some m -> resultVal + m.Checksum()
        | None -> 0u
    override this.Name = "Maze::Generator"

type MazeBFS() =
    inherit Benchmark()

    let mutable width = 0
    let mutable height = 0
    let mutable maze : MazeTypes.Maze option = None
    let mutable resultVal = 0u
    let mutable path : MazeTypes.Cell list = []

    override this.Prepare() =
        width <- int (this.ConfigVal("w"))
        height <- int (this.ConfigVal("h"))
        let newMaze = MazeTypes.Maze(width, height)
        newMaze.Generate()
        maze <- Some newMaze
        resultVal <- 0u
        path <- []

    member this.Bfs(start: MazeTypes.Cell, target: MazeTypes.Cell) =
        if start = target then [start] else

        let queue = Queue<int>()
        let visited = Array2D.zeroCreate<bool> height width
        let pathNodes = ResizeArray<BfsPathNode>()

        visited.[start.Y, start.X] <- true
        pathNodes.Add(BfsPathNode(start, -1))
        queue.Enqueue(0)

        let mutable result = []

        while queue.Count > 0 && result.IsEmpty do
            let pathId = queue.Dequeue()
            let node = pathNodes.[pathId]

            for i = 0 to node.Cell.Neighbors.Count - 1 do
                let neighbor = node.Cell.Neighbors.[i]
                if neighbor = target then
                    let mutable cur = pathId
                    let mutable res = [target]
                    while cur >= 0 do
                        res <- pathNodes.[cur].Cell :: res
                        cur <- pathNodes.[cur].Parent
                    result <- res |> List.rev
                else
                    if neighbor.IsWalkable() && not visited.[neighbor.Y, neighbor.X] then
                        visited.[neighbor.Y, neighbor.X] <- true
                        pathNodes.Add(BfsPathNode(neighbor, pathId))
                        queue.Enqueue(pathNodes.Count - 1)

        result

    member this.MidCellChecksum(path: MazeTypes.Cell list) =
        if path.IsEmpty then 0u
        else
            let cell = path.[path.Length / 2]
            uint32 (cell.X * cell.Y)

    override this.Run(_: int64) =
        match maze with
        | Some m ->
            path <- this.Bfs(m.Start, m.Finish)
            resultVal <- resultVal + uint32 path.Length
        | None -> ()

    override this.Checksum = resultVal + this.MidCellChecksum(path)
    override this.Name = "Maze::BFS"

type MazeAStar() =
    inherit Benchmark()

    let mutable width = 0
    let mutable height = 0
    let mutable maze : MazeTypes.Maze option = None
    let mutable resultVal = 0u
    let mutable path : MazeTypes.Cell list = []

    override this.Prepare() =
        width <- int (this.ConfigVal("w"))
        height <- int (this.ConfigVal("h"))
        let newMaze = MazeTypes.Maze(width, height)
        newMaze.Generate()
        maze <- Some newMaze
        resultVal <- 0u
        path <- []

    member this.Heuristic(a: MazeTypes.Cell, b: MazeTypes.Cell) =
        abs (a.X - b.X) + abs (a.Y - b.Y)

    member this.Idx(y: int, x: int) = y * width + x

    member this.AStar(start: MazeTypes.Cell, target: MazeTypes.Cell) =
        if start = target then [start] else

        let size = width * height
        let cameFrom = Array.create size -1
        let gScore = Array.create size Int32.MaxValue
        let bestF = Array.create size Int32.MaxValue

        let startIdx = this.Idx(start.Y, start.X)
        let targetIdx = this.Idx(target.Y, target.X)

        let openSet = PriorityQueue<int, int>()
        let inOpen = Array.create size false

        let fStart = this.Heuristic(start, target)
        openSet.Enqueue(startIdx, fStart)
        bestF.[startIdx] <- fStart
        gScore.[startIdx] <- 0
        inOpen.[startIdx] <- true

        let mutable result = []

        while openSet.Count > 0 && result.IsEmpty do
            let ok, currentIdx, _ = openSet.TryDequeue()  
            if ok then
                inOpen.[currentIdx] <- false

                if currentIdx = targetIdx then
                    let mutable cur = currentIdx
                    while cur <> -1 do
                        let y = cur / width
                        let x = cur % width
                        match maze with
                        | Some m -> result <- m.Cells.[y, x] :: result
                        | None -> ()
                        cur <- cameFrom.[cur]
                    result <- result |> List.rev
                else
                    let currentY = currentIdx / width
                    let currentX = currentIdx % width
                    match maze with
                    | Some m ->
                        let currentCell = m.Cells.[currentY, currentX]
                        let currentG = gScore.[currentIdx]

                        for i = 0 to currentCell.Neighbors.Count - 1 do
                            let neighbor = currentCell.Neighbors.[i]
                            if neighbor.IsWalkable() then
                                let neighborIdx = this.Idx(neighbor.Y, neighbor.X)
                                let tentativeG = currentG + 1

                                if tentativeG < gScore.[neighborIdx] then
                                    cameFrom.[neighborIdx] <- currentIdx
                                    gScore.[neighborIdx] <- tentativeG
                                    let fNew = tentativeG + this.Heuristic(neighbor, target)

                                    if fNew < bestF.[neighborIdx] then
                                        bestF.[neighborIdx] <- fNew
                                        openSet.Enqueue(neighborIdx, fNew)
                                        inOpen.[neighborIdx] <- true
                    | None -> ()

        result

    member this.MidCellChecksum(path: MazeTypes.Cell list) =
        if path.IsEmpty then 0u
        else
            let cell = path.[path.Length / 2]
            uint32 (cell.X * cell.Y)

    override this.Run(_: int64) =
        match maze with
        | Some m ->
            path <- this.AStar(m.Start, m.Finish)
            resultVal <- resultVal + uint32 path.Length
        | None -> ()

    override this.Checksum = resultVal + this.MidCellChecksum(path)
    override this.Name = "Maze::AStar"