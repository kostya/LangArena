import std/[math, algorithm, deques]
import ../benchmark
import ../helper

{.experimental: "callOperator".}  

type
  Cell = enum
    Wall, Path

  Maze = object
    width, height: int
    cells: seq[seq[Cell]]

  MazeGenerator* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    boolGrid: seq[seq[bool]]

proc newMaze(width, height: int): Maze =
  let w = if width > 5: width else: 5
  let h = if height > 5: height else: 5

  var cells = newSeq[seq[Cell]](h)
  for i in 0..<h:
    cells[i] = newSeq[Cell](w)
    for j in 0..<w:
      cells[i][j] = Wall

  result = Maze(
    width: w,
    height: h,
    cells: cells
  )

proc `()`(maze: Maze, x, y: int): Cell =
  maze.cells[y][x]

proc `()`(maze: var Maze, x, y: int): var Cell =
  maze.cells[y][x]

proc addRandomPaths(maze: var Maze) =
  let numExtraPaths = (maze.width * maze.height) div 20  

  for i in 0..<numExtraPaths:
    let x = nextInt(int32(maze.width - 2)) + 1  
    let y = nextInt(int32(maze.height - 2)) + 1

    if maze(x, y) == Wall and
       maze(x - 1, y) == Wall and
       maze(x + 1, y) == Wall and
       maze(x, y - 1) == Wall and
       maze(x, y + 1) == Wall:
      maze(x, y) = Path

proc divide(maze: var Maze, x1, y1, x2, y2: int) =
  let width = x2 - x1
  let height = y2 - y1

  if width < 2 or height < 2:
    return

  let widthForWall = max(width - 2, 0)
  let heightForWall = max(height - 2, 0)
  let widthForHole = max(width - 1, 0)
  let heightForHole = max(height - 1, 0)

  if widthForWall == 0 or heightForWall == 0 or widthForHole == 0 or heightForHole == 0:
    return

  if width > height:
    let wallRange = max(widthForWall div 2, 1)
    let wallOffset = if wallRange > 0: nextInt(wallRange.int32) * 2 else: 0
    let wallX = x1 + 2 + wallOffset

    let holeRange = max(heightForHole div 2, 1)
    let holeOffset = if holeRange > 0: nextInt(holeRange.int32) * 2 else: 0
    let holeY = y1 + 1 + holeOffset

    if wallX > x2 or holeY > y2:
      return

    for y in y1..y2:
      if y != holeY:
        maze(wallX, y) = Wall

    if wallX > x1 + 1:
      maze.divide(x1, y1, wallX - 1, y2)
    if wallX + 1 < x2:
      maze.divide(wallX + 1, y1, x2, y2)
  else:
    let wallRange = max(heightForWall div 2, 1)
    let wallOffset = if wallRange > 0: nextInt(wallRange.int32) * 2 else: 0
    let wallY = y1 + 2 + wallOffset

    let holeRange = max(widthForHole div 2, 1)
    let holeOffset = if holeRange > 0: nextInt(holeRange.int32) * 2 else: 0
    let holeX = x1 + 1 + holeOffset

    if wallY > y2 or holeX > x2:
      return

    for x in x1..x2:
      if x != holeX:
        maze(x, wallY) = Wall

    if wallY > y1 + 1:
      maze.divide(x1, y1, x2, wallY - 1)
    if wallY + 1 < y2:
      maze.divide(x1, wallY + 1, x2, y2)

proc isConnected(maze: Maze, start, goal: (int, int)): bool =
  let (startX, startY) = start
  let (goalX, goalY) = goal

  if startX >= maze.width or startY >= maze.height or goalX >= maze.width or goalY >= maze.height:
    return false

  var visited = newSeq[seq[bool]](maze.height)
  for i in 0..<maze.height:
    visited[i] = newSeq[bool](maze.width)
    for j in 0..<maze.width:
      visited[i][j] = false

  var queue = initDeque[(int, int)]()

  visited[startY][startX] = true
  queue.addLast((startX, startY))

  while queue.len > 0:
    let (x, y) = queue.popFirst()

    if (x, y) == (goalX, goalY):
      return true

    if y > 0 and maze(x, y - 1) == Path and not visited[y - 1][x]:
      visited[y - 1][x] = true
      queue.addLast((x, y - 1))

    if x + 1 < maze.width and maze(x + 1, y) == Path and not visited[y][x + 1]:
      visited[y][x + 1] = true
      queue.addLast((x + 1, y))

    if y + 1 < maze.height and maze(x, y + 1) == Path and not visited[y + 1][x]:
      visited[y + 1][x] = true
      queue.addLast((x, y + 1))

    if x > 0 and maze(x - 1, y) == Path and not visited[y][x - 1]:
      visited[y][x - 1] = true
      queue.addLast((x - 1, y))

  false

proc generate(maze: var Maze) =
  if maze.width < 5 or maze.height < 5:
    for x in 0..<maze.width:
      maze(x, maze.height div 2) = Path
    return

  maze.divide(0, 0, maze.width - 1, maze.height - 1)
  maze.addRandomPaths()

proc toBoolGrid(maze: Maze): seq[seq[bool]] =
  result = newSeq[seq[bool]](maze.height)
  for y in 0..<maze.height:
    result[y] = newSeq[bool](maze.width)
    for x in 0..<maze.width:
      result[y][x] = maze(x, y) == Path

proc generateWalkableMaze*(width, height: int): seq[seq[bool]] =
  var maze = newMaze(width, height)
  maze.generate()

  let start = (1, 1)
  let goal = (width - 2, height - 2)

  if not maze.isConnected(start, goal):
    for y in 0..<height:
      for x in 0..<width:
        if x < maze.width and y < maze.height:
          if x == 1 or y == 1 or x == width - 2 or y == height - 2:
            maze(x, y) = Path

  maze.toBoolGrid()

proc gridChecksum(grid: seq[seq[bool]]): uint32 =
  const
    FNV_OFFSET_BASIS = 2166136261'u32
    FNV_PRIME = 16777619'u32

  var hasher = FNV_OFFSET_BASIS

  for y in 0..<grid.len:
    let row = grid[y]
    for x in 0..<row.len:
      if row[x]:
        let jSquared = uint32(x * x)
        hasher = (hasher xor jSquared) * FNV_PRIME

  hasher

proc newMazeGenerator(): Benchmark =
  MazeGenerator()

method name(self: MazeGenerator): string = "MazeGenerator"

method prepare(self: MazeGenerator) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.resultVal = 0

method run(self: MazeGenerator, iteration_id: int) =
  self.boolGrid = generateWalkableMaze(self.width.int, self.height.int)

method checksum(self: MazeGenerator): uint32 =
  gridChecksum(self.boolGrid)

registerBenchmark("MazeGenerator", newMazeGenerator)