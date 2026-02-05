namespace Benchmarks

open System

type Cell = Dead = 0uy | Alive = 1uy

type Grid(width: int, height: int) =
    let size = width * height
    let mutable cells = Array.zeroCreate<Cell> size
    let mutable buffer = Array.zeroCreate<Cell> size

    member _.Width = width
    member _.Height = height

    member private this.Index(x, y) = y * width + x

    member this.Get(x, y) = cells.[this.Index(x, y)]

    member this.Set(x, y, value) = 
        cells.[this.Index(x, y)] <- value

    member private this.CountNeighbors(x, y, cellsArray: Cell[]) =
        let yPrev = if y = 0 then height - 1 else y - 1
        let yNext = if y = height - 1 then 0 else y + 1
        let xPrev = if x = 0 then width - 1 else x - 1
        let xNext = if x = width - 1 then 0 else x + 1

        let mutable count = 0

        let idx = yPrev * width
        if cellsArray.[idx + xPrev] = Cell.Alive then count <- count + 1
        if cellsArray.[idx + x] = Cell.Alive then count <- count + 1
        if cellsArray.[idx + xNext] = Cell.Alive then count <- count + 1

        let idx = y * width
        if cellsArray.[idx + xPrev] = Cell.Alive then count <- count + 1
        if cellsArray.[idx + xNext] = Cell.Alive then count <- count + 1

        let idx = yNext * width
        if cellsArray.[idx + xPrev] = Cell.Alive then count <- count + 1
        if cellsArray.[idx + x] = Cell.Alive then count <- count + 1
        if cellsArray.[idx + xNext] = Cell.Alive then count <- count + 1

        count

    member this.NextGeneration() : Grid =

        for y in 0 .. height - 1 do
            let yIdx = y * width

            for x in 0 .. width - 1 do
                let idx = yIdx + x

                let neighbors = this.CountNeighbors(x, y, cells)
                let current = cells.[idx]

                let nextState =
                    match current with
                    | Cell.Alive when neighbors = 2 || neighbors = 3 -> Cell.Alive
                    | Cell.Dead when neighbors = 3 -> Cell.Alive
                    | _ -> Cell.Dead

                buffer.[idx] <- nextState

        let temp = cells
        cells <- buffer
        buffer <- temp

        this

    member _.ComputeHash() =
        let mutable hash = 2166136261u

        for i in 0 .. cells.Length - 1 do
            let alive = if cells.[i] = Cell.Alive then 1u else 0u
            hash <- (hash ^^^ alive) * 16777619u

        hash

type GameOfLife() =
    inherit Benchmark()

    let mutable grid : Grid option = None

    override this.Checksum = 
        match grid with
        | Some g -> g.ComputeHash()
        | None -> 0u

    override this.Prepare() =
        let width = Helper.Config_i64("GameOfLife", "w") |> int
        let height = Helper.Config_i64("GameOfLife", "h") |> int

        let g = Grid(width, height)

        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                if Helper.NextFloat(1.0) < 0.1 then
                    g.Set(x, y, Cell.Alive)

        grid <- Some g

    override this.Run(IterationId: int64) =
        match grid with
        | Some g -> g.NextGeneration() |> ignore
        | None -> ()