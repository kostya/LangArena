import std/[math, random]
import ../benchmark
import ../helper

type
  Cell = enum
    Dead, Alive

  Grid = object
    width, height: int
    cells: seq[Cell]
    buffer: seq[Cell]

  GameOfLife* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    grid: Grid

proc newGrid(width, height: int): Grid =
  let size = width * height
  result = Grid(
    width: width,
    height: height,
    cells: newSeq[Cell](size),
    buffer: newSeq[Cell](size)
  )

proc `[]`(grid: Grid, x, y: int): Cell =
  grid.cells[y * grid.width + x]

proc `[]=`(grid: var Grid, x, y: int, cell: Cell) =
  grid.cells[y * grid.width + x] = cell

proc countNeighbors(grid: Grid, x, y: int): int =
  let
    yPrev = if y == 0: grid.height - 1 else: y - 1
    yNext = if y == grid.height - 1: 0 else: y + 1
    xPrev = if x == 0: grid.width - 1 else: x - 1
    xNext = if x == grid.width - 1: 0 else: x + 1

  var count = 0
  count += int(grid[xPrev, yPrev] == Alive)
  count += int(grid[x, yPrev] == Alive)
  count += int(grid[xNext, yPrev] == Alive)
  count += int(grid[xPrev, y] == Alive)
  count += int(grid[xNext, y] == Alive)
  count += int(grid[xPrev, yNext] == Alive)
  count += int(grid[x, yNext] == Alive)
  count += int(grid[xNext, yNext] == Alive)
  count

proc nextGeneration(grid: var Grid) =
  for y in 0..<grid.height:
    let yIdx = y * grid.width
    for x in 0..<grid.width:
      let idx = yIdx + x
      let neighbors = grid.countNeighbors(x, y)
      let current = grid.cells[idx]

      var nextState = Dead
      if current == Alive:
        nextState = if neighbors == 2 or neighbors == 3: Alive else: Dead
      else:
        nextState = if neighbors == 3: Alive else: Dead

      grid.buffer[idx] = nextState

  swap(grid.cells, grid.buffer)

proc computeHash(grid: Grid): uint32 =
  const
    FNV_OFFSET_BASIS = 2166136261'u32
    FNV_PRIME = 16777619'u32

  var hash = FNV_OFFSET_BASIS
  for cell in grid.cells:
    let alive = uint32(cell == Alive)
    hash = (hash xor alive) * FNV_PRIME
  hash

proc newGameOfLife(): Benchmark =
  GameOfLife()

method name(self: GameOfLife): string = "GameOfLife"

method prepare(self: GameOfLife) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.grid = newGrid(self.width.int, self.height.int)
  self.resultVal = 0

  for y in 0..<self.height.int:
    for x in 0..<self.width.int:
      if nextFloat() < 0.1:
        self.grid[x, y] = Alive

method run(self: GameOfLife, iteration_id: int) =
  self.grid.nextGeneration()

method checksum(self: GameOfLife): uint32 =
  self.grid.computeHash()

registerBenchmark("GameOfLife", newGameOfLife)