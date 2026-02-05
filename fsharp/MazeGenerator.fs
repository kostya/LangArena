namespace Benchmarks

open System
open System.Collections.Generic

module MazeTypes =
    type Cell = Wall = 0 | Path = 1

    type Maze(width: int, height: int) =
        let w = if width > 5 then width else 5
        let h = if height > 5 then height else 5
        let cells = Array2D.create h w Cell.Wall

        member _.Width = w
        member _.Height = h

        member _.Get(x, y) = cells.[y, x]
        member _.Set(x, y, cell) = cells.[y, x] <- cell

        member private this.Divide(x1: int, y1: int, x2: int, y2: int) =
            let width = x2 - x1
            let height = y2 - y1

            if width < 2 || height < 2 then ()
            else
                let widthForWall = width - 2
                let heightForWall = height - 2
                let widthForHole = width - 1
                let heightForHole = height - 1

                if widthForWall <= 0 || heightForWall <= 0 ||
                   widthForHole <= 0 || heightForHole <= 0 then ()
                else
                    if width > height then
                        let wallRange = max (widthForWall / 2) 1
                        let wallOffset = if wallRange > 0 then Helper.NextInt(wallRange) * 2 else 0
                        let wallX = x1 + 2 + wallOffset

                        let holeRange = max (heightForHole / 2) 1
                        let holeOffset = if holeRange > 0 then Helper.NextInt(holeRange) * 2 else 0
                        let holeY = y1 + 1 + holeOffset

                        if wallX <= x2 && holeY <= y2 then
                            for y = y1 to y2 do
                                if y <> holeY then this.Set(wallX, y, Cell.Wall)

                            if wallX > x1 + 1 then this.Divide(x1, y1, wallX - 1, y2)
                            if wallX + 1 < x2 then this.Divide(wallX + 1, y1, x2, y2)
                    else
                        let wallRange = max (heightForWall / 2) 1
                        let wallOffset = if wallRange > 0 then Helper.NextInt(wallRange) * 2 else 0
                        let wallY = y1 + 2 + wallOffset

                        let holeRange = max (widthForHole / 2) 1
                        let holeOffset = if holeRange > 0 then Helper.NextInt(holeRange) * 2 else 0
                        let holeX = x1 + 1 + holeOffset

                        if wallY <= y2 && holeX <= x2 then
                            for x = x1 to x2 do
                                if x <> holeX then this.Set(x, wallY, Cell.Wall)

                            if wallY > y1 + 1 then this.Divide(x1, y1, x2, wallY - 1)
                            if wallY + 1 < y2 then this.Divide(x1, wallY + 1, x2, y2)

        member private this.AddRandomPaths() =
            let numExtraPaths = (w * h) / 20

            for _ = 1 to numExtraPaths do
                let x = Helper.NextInt(w - 2) + 1
                let y = Helper.NextInt(h - 2) + 1

                if this.Get(x, y) = Cell.Wall &&
                   this.Get(x - 1, y) = Cell.Wall &&
                   this.Get(x + 1, y) = Cell.Wall &&
                   this.Get(x, y - 1) = Cell.Wall &&
                   this.Get(x, y + 1) = Cell.Wall then
                    this.Set(x, y, Cell.Path)

        member private this.IsConnectedImpl(startX, startY, goalX, goalY) =
            if startX >= w || startY >= h || goalX >= w || goalY >= h then false
            else
                let visited = Array2D.zeroCreate h w
                let queue = Queue<int * int>()

                visited.[startY, startX] <- true
                queue.Enqueue((startX, startY))

                let mutable found = false

                while queue.Count > 0 && not found do
                    let (x, y) = queue.Dequeue()

                    if x = goalX && y = goalY then
                        found <- true
                    else
                        if y > 0 && this.Get(x, y - 1) = Cell.Path && not visited.[y - 1, x] then
                            visited.[y - 1, x] <- true
                            queue.Enqueue((x, y - 1))

                        if x + 1 < w && this.Get(x + 1, y) = Cell.Path && not visited.[y, x + 1] then
                            visited.[y, x + 1] <- true
                            queue.Enqueue((x + 1, y))

                        if y + 1 < h && this.Get(x, y + 1) = Cell.Path && not visited.[y + 1, x] then
                            visited.[y + 1, x] <- true
                            queue.Enqueue((x, y + 1))

                        if x > 0 && this.Get(x - 1, y) = Cell.Path && not visited.[y, x - 1] then
                            visited.[y, x - 1] <- true
                            queue.Enqueue((x - 1, y))

                found

        member this.Generate() =
            if w < 5 || h < 5 then
                for x = 0 to w - 1 do
                    this.Set(x, h / 2, Cell.Path)
            else
                this.Divide(0, 0, w - 1, h - 1)
                this.AddRandomPaths()

        member this.ToBoolGrid() =
            Array2D.init h w (fun y x -> this.Get(x, y) = Cell.Path)

        member this.IsConnected(startX, startY, goalX, goalY) =
            this.IsConnectedImpl(startX, startY, goalX, goalY)

        static member GenerateWalkableMaze(width: int, height: int) =
            let maze = Maze(width, height)
            maze.Generate()

            let startX = 1
            let startY = 1
            let goalX = width - 2
            let goalY = height - 2

            if not (maze.IsConnected(startX, startY, goalX, goalY)) then
                for x = 0 to width - 1 do
                    for y = 0 to height - 1 do
                        if x < maze.Width && y < maze.Height then
                            if x = 1 || y = 1 || x = width - 2 || y = height - 2 then
                                maze.Set(x, y, Cell.Path)

            maze.ToBoolGrid()

type MazeGenerator() =
    inherit Benchmark()

    let mutable width = 0
    let mutable height = 0
    let mutable boolGrid = Array2D.zeroCreate<bool> 0 0
    let mutable result = 0u

    let gridChecksum (grid: bool[,]) =
        let mutable hasher = 2166136261u
        let prime = 16777619u

        for i = 0 to Array2D.length1 grid - 1 do
            for j = 0 to Array2D.length2 grid - 1 do
                if grid.[i, j] then
                    let jSquared = uint32 (j * j)
                    hasher <- (hasher ^^^ jSquared) * prime

        hasher

    override this.Checksum = result

    override this.Prepare() =
        width <- int (this.ConfigVal("w"))
        height <- int (this.ConfigVal("h"))
        boolGrid <- Array2D.zeroCreate<bool> 0 0
        result <- 0u

    override this.Run(_: int64) =
        boolGrid <- MazeTypes.Maze.GenerateWalkableMaze(width, height)
        result <- gridChecksum boolGrid