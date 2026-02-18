namespace Benchmarks

open System

type Cell() =
    member val Alive = false with get, set
    member val NextState = false with get, set
    member val Neighbors = Array.zeroCreate<Cell> 8 with get
    member val NeighborCount = 0 with get, set

    member this.AddNeighbor(cell: Cell) =
        this.Neighbors.[this.NeighborCount] <- cell
        this.NeighborCount <- this.NeighborCount + 1

    member this.ComputeNextState() =
        let mutable aliveNeighbors = 0
        for i in 0 .. this.NeighborCount - 1 do
            if this.Neighbors.[i].Alive then
                aliveNeighbors <- aliveNeighbors + 1

        this.NextState <-
            if this.Alive then
                aliveNeighbors = 2 || aliveNeighbors = 3
            else
                aliveNeighbors = 3

    member this.Update() =
        this.Alive <- this.NextState

type Grid(width: int, height: int) =
    let cells = Array2D.init height width (fun _ _ -> Cell())

    do

        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                let cell = cells.[y, x]
                for dy in -1 .. 1 do
                    for dx in -1 .. 1 do
                        if not (dx = 0 && dy = 0) then
                            let ny = (y + dy + height) % height
                            let nx = (x + dx + width) % width
                            cell.AddNeighbor(cells.[ny, nx])

    member _.Width = width
    member _.Height = height

    member this.NextGeneration() =

        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                cells.[y, x].ComputeNextState()

        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                cells.[y, x].Update()

        this

    member _.CountAlive() =
        let mutable count = 0
        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                if cells.[y, x].Alive then
                    count <- count + 1
        count

    member _.ComputeHash() =
        let mutable hash = 2166136261u
        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                let alive = if cells.[y, x].Alive then 1u else 0u
                hash <- (hash ^^^ alive) * 16777619u
        hash

    member _.GetCells() = cells

type GameOfLife() =
    inherit Benchmark()

    let mutable grid : Grid option = None

    override this.Checksum =
        match grid with
        | Some g -> g.ComputeHash() + uint32 (g.CountAlive())
        | None -> 0u

    override this.Prepare() =
        let width = Helper.Config_i64("GameOfLife", "w") |> int
        let height = Helper.Config_i64("GameOfLife", "h") |> int

        let g = Grid(width, height)

        for y in 0 .. height - 1 do
            for x in 0 .. width - 1 do
                if Helper.NextFloat(1.0) < 0.1 then
                    g.GetCells().[y, x].Alive <- true

        grid <- Some g

    override this.Run(IterationId: int64) =
        match grid with
        | Some g -> g.NextGeneration() |> ignore
        | None -> ()