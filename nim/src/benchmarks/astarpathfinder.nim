import std/[math, algorithm, deques, heapqueue, sequtils]
import ../benchmark
import ../helper
import mazegenerator  

type
  Node = object
    x, y, fScore: int

  AStarPathfinder* = ref object of Benchmark
    resultVal: uint32
    width, height: int32
    startX, startY: int
    goalX, goalY: int
    mazeGrid: seq[seq[bool]]
    gScores: seq[int]
    cameFrom: seq[int]

proc `<`(a, b: Node): bool =
  if a.fScore != b.fScore:
    return a.fScore < b.fScore
  if a.y != b.y:
    return a.y < b.y
  return a.x < b.x

proc newAStarPathfinder(): Benchmark =
  AStarPathfinder()

method name(self: AStarPathfinder): string = "AStarPathfinder"

const
  INF = high(int)
  STRAIGHT_COST = 1000

proc heuristic(x1, y1, x2, y2: int): int =
  abs(x1 - x2) + abs(y1 - y2)

proc packCoords(x, y, width: int): int =
  y * width + x

proc unpackCoords(idx, width: int): (int, int) =
  (idx mod width, idx div width)

method prepare(self: AStarPathfinder) =
  self.width = int32(self.config_val("w"))
  self.height = int32(self.config_val("h"))
  self.startX = 1
  self.startY = 1
  self.goalX = self.width.int - 2
  self.goalY = self.height.int - 2

  reset()
  self.mazeGrid = generateWalkableMaze(self.width.int, self.height.int)

  let size = self.width.int * self.height.int
  self.gScores = newSeq[int](size)
  self.cameFrom = newSeq[int](size)
  self.resultVal = 0

method run(self: AStarPathfinder, iteration_id: int) =
  let
    width = self.width.int
    height = self.height.int
    size = width * height
    startIdx = packCoords(self.startX, self.startY, width)
    goalIdx = packCoords(self.goalX, self.goalY, width)

  for i in 0..<size:
    self.gScores[i] = INF
    self.cameFrom[i] = -1

  var openSet = initHeapQueue[Node]()
  self.gScores[startIdx] = 0
  openSet.push(Node(
    x: self.startX,
    y: self.startY,
    fScore: heuristic(self.startX, self.startY, self.goalX, self.goalY)
  ))

  var nodesExplored = 0
  let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

  while openSet.len > 0:
    let current = openSet.pop()
    nodesExplored.inc

    if current.x == self.goalX and current.y == self.goalY:

      var path: seq[(int, int)]
      var x = current.x
      var y = current.y

      while x != self.startX or y != self.startY:
        path.add((x, y))
        let idx = packCoords(x, y, width)
        let packed = self.cameFrom[idx]
        if packed == -1:
          break

        (x, y) = unpackCoords(packed, width)

      path.add((self.startX, self.startY))
      path.reverse()

      var localResult: int64 = 0
      if path.len > 0:
        localResult = (localResult shl 5) + int64(path.len)
      localResult = (localResult shl 5) + int64(nodesExplored)
      self.resultVal = self.resultVal + uint32(localResult)
      return

    let currentIdx = packCoords(current.x, current.y, width)
    let currentG = self.gScores[currentIdx]

    for (dx, dy) in directions:
      let nx = current.x + dx
      let ny = current.y + dy

      if nx < 0 or nx >= width or ny < 0 or ny >= height:
        continue
      if not self.mazeGrid[ny][nx]:
        continue

      let tentativeG = currentG + STRAIGHT_COST
      let neighborIdx = packCoords(nx, ny, width)

      if tentativeG < self.gScores[neighborIdx]:
        self.cameFrom[neighborIdx] = currentIdx
        self.gScores[neighborIdx] = tentativeG

        let fScore = tentativeG + heuristic(nx, ny, self.goalX, self.goalY)
        openSet.push(Node(x: nx, y: ny, fScore: fScore))

  var localResult: int64 = 0
  localResult = (localResult shl 5) + int64(nodesExplored)
  self.resultVal = self.resultVal + uint32(localResult)

method checksum(self: AStarPathfinder): uint32 =
  self.resultVal

registerBenchmark("AStarPathfinder", newAStarPathfinder)