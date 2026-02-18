import std/[math, algorithm, deques, tables, heapqueue]
import ../benchmark
import ../helper

type
  CellKind* = enum
    Wall = 0
    Space = 1
    Start = 2
    Finish = 3
    Border = 4
    Path = 5

  Cell* = ref object
    kind*: CellKind
    neighbors*: seq[Cell]
    x*, y*: int

  Maze* = ref object
    width*, height*: int
    cells*: seq[seq[Cell]]
    start*, finish*: Cell

  MazeGenerator* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    maze: Maze

  PathNode* = object
    cell: Cell
    parent: int

  MazeBFS* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    maze: Maze
    path: seq[Cell]

  Item* = object
    priority: int
    vertex: int

  MazeAStar* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    maze: Maze
    path: seq[Cell]

proc newCell(x, y: int): Cell
proc isWalkable*(kind: CellKind): bool
proc addNeighbor*(cell: Cell, neighbor: Cell)
proc reset*(cell: Cell)
proc newMaze*(width, height: int): Maze
proc updateNeighbors*(maze: Maze)
proc reset*(maze: Maze)
proc dig*(maze: Maze, startCell: Cell)
proc ensureOpenFinish*(maze: Maze, startCell: Cell)
proc generate*(maze: Maze)
proc middleCell*(maze: Maze): Cell
proc checksum*(maze: Maze): uint32
proc printToConsole*(maze: Maze)

proc newCell(x, y: int): Cell =
  new(result)
  result.kind = Wall
  result.neighbors = @[]
  result.x = x
  result.y = y

proc isWalkable*(kind: CellKind): bool =
  kind in {Space, Start, Finish}

proc addNeighbor*(cell: Cell, neighbor: Cell) =
  cell.neighbors.add(neighbor)

proc reset*(cell: Cell) =
  if cell.kind == Space:
    cell.kind = Wall

proc newMaze*(width, height: int): Maze =
  new(result)
  let w = max(width, 5)
  let h = max(height, 5)

  result.width = w
  result.height = h
  result.cells = newSeq[seq[Cell]](h)

  for y in 0..<h:
    result.cells[y] = newSeq[Cell](w)
    for x in 0..<w:
      result.cells[y][x] = newCell(x, y)

  result.start = result.cells[1][1]
  result.finish = result.cells[h-2][w-2]
  result.start.kind = Start
  result.finish.kind = Finish

  updateNeighbors(result)

proc updateNeighbors*(maze: Maze) =
  for y in 0..<maze.height:
    for x in 0..<maze.width:
      let cell = maze.cells[y][x]
      cell.neighbors.setLen(0)

      if x > 0 and y > 0 and x < maze.width - 1 and y < maze.height - 1:
        cell.addNeighbor(maze.cells[y-1][x])
        cell.addNeighbor(maze.cells[y+1][x])
        cell.addNeighbor(maze.cells[y][x+1])
        cell.addNeighbor(maze.cells[y][x-1])

        for _ in 0..<4:
          let i = nextInt(4)
          let j = nextInt(4)
          if i != j:
            swap(cell.neighbors[i], cell.neighbors[j])
      else:
        cell.kind = Border

proc reset*(maze: Maze) =
  for row in maze.cells:
    for cell in row:
      reset(cell)
  maze.start.kind = Start
  maze.finish.kind = Finish

proc dig*(maze: Maze, startCell: Cell) =
  var stack = newSeq[Cell]()
  stack.add(startCell)

  while stack.len > 0:
    let cell = stack.pop()

    var walkable = 0
    for n in cell.neighbors:
      if n.kind.isWalkable:
        inc walkable

    if walkable == 1:
      cell.kind = Space
      for n in cell.neighbors:
        if n.kind == Wall:
          stack.add(n)

proc ensureOpenFinish*(maze: Maze, startCell: Cell) =
  var stack = newSeq[Cell]()
  stack.add(startCell)

  while stack.len > 0:
    let cell = stack.pop()

    cell.kind = Space

    var walkable = 0
    for n in cell.neighbors:
      if n.kind.isWalkable:
        inc walkable

    if walkable <= 1:
      for n in cell.neighbors:
        if n.kind == Wall:
          stack.add(n)

proc generate*(maze: Maze) =
  for n in maze.start.neighbors:
    if n.kind == Wall:
      maze.dig(n)

  for n in maze.finish.neighbors:
    if n.kind == Wall:
      maze.ensureOpenFinish(n)

proc middleCell*(maze: Maze): Cell =
  maze.cells[maze.height div 2][maze.width div 2]

proc checksum*(maze: Maze): uint32 =
  var hasher = 2166136261'u32
  const prime = 16777619'u32

  for y in 0..<maze.height:
    for x in 0..<maze.width:
      if maze.cells[y][x].kind == Space:
        let val = uint32(x * y)
        hasher = (hasher xor val) * prime

  hasher

proc printToConsole*(maze: Maze) =
  for y in 0..<maze.height:
    for x in 0..<maze.width:
      case maze.cells[y][x].kind
      of Space: stdout.write(" ")
      of Wall: stdout.write("\e[34m#\e[0m")
      of Border: stdout.write("\e[31mO\e[0m")
      of Start: stdout.write("\e[32m>\e[0m")
      of Finish: stdout.write("\e[32m<\e[0m")
      of Path: stdout.write("\e[33m.\e[0m")
    echo ""
  echo ""

proc newMazeGenerator*(): Benchmark =
  MazeGenerator()

method name(self: MazeGenerator): string = "Maze::Generator"

method prepare(self: MazeGenerator) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.maze = newMaze(self.width.int, self.height.int)
  self.resultVal = 0

method run(self: MazeGenerator, iteration_id: int) =
  reset(self.maze)
  generate(self.maze)
  self.resultVal += uint32(self.maze.middleCell().kind)

method checksum(self: MazeGenerator): uint32 =
  self.resultVal + self.maze.checksum()

registerBenchmark("Maze::Generator", newMazeGenerator)

proc newMazeBFS*(): Benchmark =
  MazeBFS()

method name(self: MazeBFS): string = "Maze::BFS"

method prepare(self: MazeBFS) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.maze = newMaze(self.width.int, self.height.int)
  generate(self.maze)
  self.resultVal = 0
  self.path = @[]

proc bfs(maze: Maze, start, target: Cell): seq[Cell] =
  if start == target:
    return @[start]

  var queue = initDeque[int]()
  var visited = newSeq[seq[bool]](maze.height)
  for y in 0..<maze.height:
    visited[y] = newSeq[bool](maze.width)
    for x in 0..<maze.width:
      visited[y][x] = false

  var pathNodes = newSeq[PathNode]()

  visited[start.y][start.x] = true
  pathNodes.add(PathNode(cell: start, parent: -1))
  queue.addLast(0)

  while queue.len > 0:
    let pathId = queue.popFirst()
    let node = pathNodes[pathId]

    for neighbor in node.cell.neighbors:
      if neighbor == target:
        var cur = pathId
        var res = @[target]
        while cur >= 0:
          res.add(pathNodes[cur].cell)
          cur = pathNodes[cur].parent
        return res.reversed()

      if neighbor.kind.isWalkable and not visited[neighbor.y][neighbor.x]:
        visited[neighbor.y][neighbor.x] = true
        pathNodes.add(PathNode(cell: neighbor, parent: pathId))
        queue.addLast(pathNodes.len - 1)

  @[]

proc midCellChecksum(path: seq[Cell]): uint32 =
  if path.len == 0: return 0
  let cell = path[path.len div 2]
  uint32(cell.x * cell.y)

method run(self: MazeBFS, iteration_id: int) =
  self.path = bfs(self.maze, self.maze.start, self.maze.finish)
  self.resultVal += uint32(self.path.len)

method checksum(self: MazeBFS): uint32 =
  self.resultVal + midCellChecksum(self.path)

registerBenchmark("Maze::BFS", newMazeBFS)

proc `<`(a, b: Item): bool =
  if a.priority != b.priority:
    a.priority < b.priority
  else:
    a.vertex < b.vertex

proc newMazeAStar*(): Benchmark =
  MazeAStar()

method name(self: MazeAStar): string = "Maze::AStar"

method prepare(self: MazeAStar) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.maze = newMaze(self.width.int, self.height.int)
  generate(self.maze)
  self.resultVal = 0
  self.path = @[]

proc heuristic(a, b: Cell): int =
  abs(a.x - b.x) + abs(a.y - b.y)

proc idx(y, x, width: int): int =
  y * width + x

proc astar(maze: Maze, start, target: Cell, width, height: int): seq[Cell] =
  if start == target:
    return @[start]

  let size = width * height
  var cameFrom = newSeq[int](size)
  var gScore = newSeq[int](size)
  var bestF = newSeq[int](size)

  for i in 0..<size:
    cameFrom[i] = -1
    gScore[i] = high(int)
    bestF[i] = high(int)

  let startIdx = idx(start.y, start.x, width)
  let targetIdx = idx(target.y, target.x, width)

  var openSet = initHeapQueue[Item]()
  var inOpen = newSeq[bool](size)

  gScore[startIdx] = 0
  let fStart = heuristic(start, target)
  openSet.push(Item(priority: fStart, vertex: startIdx))
  bestF[startIdx] = fStart
  inOpen[startIdx] = true

  while openSet.len > 0:
    let current = openSet.pop()
    let currentIdx = current.vertex
    inOpen[currentIdx] = false

    if currentIdx == targetIdx:
      var cur = currentIdx
      var res = newSeq[Cell]()
      while cur != -1:
        let y = cur div width
        let x = cur mod width
        res.add(maze.cells[y][x])
        cur = cameFrom[cur]
      return res.reversed()

    let currentY = currentIdx div width
    let currentX = currentIdx mod width
    let currentCell = maze.cells[currentY][currentX]
    let currentG = gScore[currentIdx]

    for neighbor in currentCell.neighbors:
      if not neighbor.kind.isWalkable:
        continue

      let neighborIdx = idx(neighbor.y, neighbor.x, width)
      let tentativeG = currentG + 1

      if tentativeG < gScore[neighborIdx]:
        cameFrom[neighborIdx] = currentIdx
        gScore[neighborIdx] = tentativeG
        let fNew = tentativeG + heuristic(neighbor, target)

        if fNew < bestF[neighborIdx]:
          bestF[neighborIdx] = fNew
          openSet.push(Item(priority: fNew, vertex: neighborIdx))
          inOpen[neighborIdx] = true

  @[]

method run(self: MazeAStar, iteration_id: int) =
  self.path = astar(self.maze, self.maze.start, self.maze.finish,
                    self.maze.width, self.maze.height)
  self.resultVal += uint32(self.path.len)

method checksum(self: MazeAStar): uint32 =
  self.resultVal + midCellChecksum(self.path)

registerBenchmark("Maze::AStar", newMazeAStar)
