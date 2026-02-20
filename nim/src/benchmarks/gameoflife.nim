import std/[math, random, sequtils]
import ../benchmark
import ../helper

type
  CellObj = object
    alive: bool
    nextState: bool
    neighbors: seq[ref CellObj]

  Cell* = ref CellObj

  Grid* = ref object
    width, height: int
    cells: seq[seq[Cell]]

  GameOfLife* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    grid: Grid

proc newCell(): Cell =
  new(result)
  result.alive = false
  result.nextState = false
  result.neighbors = @[]

proc addNeighbor(cell: Cell, neighbor: Cell) =
  cell.neighbors.add(neighbor)

proc computeNextState(cell: Cell) =
  var aliveNeighbors = 0
  for n in cell.neighbors:
    if n.alive:
      inc aliveNeighbors

  if cell.alive:
    cell.nextState = aliveNeighbors == 2 or aliveNeighbors == 3
  else:
    cell.nextState = aliveNeighbors == 3

proc update(cell: Cell) =
  cell.alive = cell.nextState

proc newGrid(width, height: int): Grid =
  new(result)
  result.width = width
  result.height = height
  result.cells = newSeqWith(height, newSeqWith(width, newCell()))

  for y in 0..<height:
    for x in 0..<width:
      let cell = result.cells[y][x]

      for dy in -1..1:
        for dx in -1..1:
          if dx == 0 and dy == 0:
            continue

          let ny = (y + dy + height) mod height
          let nx = (x + dx + width) mod width

          cell.addNeighbor(result.cells[ny][nx])

proc nextGeneration(grid: Grid) =

  for row in grid.cells:
    for cell in row:
      cell.computeNextState()

  for row in grid.cells:
    for cell in row:
      cell.update()

proc countAlive(grid: Grid): uint32 =
  result = 0
  for row in grid.cells:
    for cell in row:
      if cell.alive:
        inc result

proc computeHash(grid: Grid): uint32 =
  const
    FNV_OFFSET_BASIS = 2166136261'u32
    FNV_PRIME = 16777619'u32

  result = FNV_OFFSET_BASIS
  for row in grid.cells:
    for cell in row:
      let alive = if cell.alive: 1'u32 else: 0'u32
      result = (result xor alive) * FNV_PRIME

proc newGameOfLife(): Benchmark =
  GameOfLife()

method name(self: GameOfLife): string = "GameOfLife"

method prepare(self: GameOfLife) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.grid = newGrid(self.width.int, self.height.int)
  self.resultVal = 0

  for row in self.grid.cells:
    for cell in row:
      if nextFloat() < 0.1:
        cell.alive = true

method run(self: GameOfLife, iteration_id: int) =
  self.grid.nextGeneration()

method checksum(self: GameOfLife): uint32 =
  let alive = self.grid.countAlive()
  result = self.grid.computeHash() + alive

registerBenchmark("GameOfLife", newGameOfLife)
