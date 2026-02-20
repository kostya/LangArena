import std/[random, deques]
import ../benchmark
import ../helper

type
  Graph* = ref object
    vertices*: int
    jumps*: int
    jumpLen*: int
    adj*: seq[seq[int]]

  GraphPathBenchmark* = ref object of Benchmark
    graph*: Graph
    resultVal*: uint32

  GraphPathBFS* = ref object of GraphPathBenchmark
  GraphPathDFS* = ref object of GraphPathBenchmark
  GraphPathAStar* = ref object of GraphPathBenchmark

proc newGraph(vertices, jumps, jumpLen: int): Graph =
  result = Graph(
    vertices: vertices,
    jumps: jumps,
    jumpLen: jumpLen,
    adj: newSeq[seq[int]](vertices)
  )

proc addEdge(g: Graph, u, v: int) =
  g.adj[u].add(v)
  g.adj[v].add(u)

proc generateRandom(g: Graph) =

  for i in 1..<g.vertices:
    addEdge(g, i, i-1)

  for v in 0..<g.vertices:
    let numJumps = nextInt(int32(g.jumps))
    for _ in 0..<numJumps:
      let offset = nextInt(int32(g.jumpLen)) - int32(g.jumpLen div 2)
      let u = v + offset
      if u >= 0 and u < g.vertices and u != v:
        addEdge(g, v, u)

method prepare(self: GraphPathBenchmark) =
  let vertices = int(self.config_val("vertices"))
  let jumps = int(self.config_val("jumps"))
  let jumpLen = int(self.config_val("jump_len"))

  self.graph = newGraph(vertices, jumps, jumpLen)
  reset()
  self.graph.generateRandom()
  self.resultVal = 0

method test*(self: GraphPathBenchmark): int64 {.base.} =
  raise newException(ValueError, "Not implemented")

method run(self: GraphPathBenchmark, iteration_id: int) =
  let total = self.test()
  self.resultVal = self.resultVal + uint32(total)

method checksum(self: GraphPathBenchmark): uint32 =
  self.resultVal

proc newGraphPathBFS(): Benchmark =
  GraphPathBFS()

method name(self: GraphPathBFS): string = "GraphPathBFS"

proc bfsShortestPath(g: Graph, start, target: int): int =
  if start == target:
    return 0

  var visited = newSeq[bool](g.vertices)
  var queue = initDeque[(int, int)]()

  visited[start] = true
  queue.addLast((start, 0))

  while queue.len > 0:
    let (v, dist) = queue.popFirst()

    for neighbor in g.adj[v]:
      if neighbor == target:
        return dist + 1

      if not visited[neighbor]:
        visited[neighbor] = true
        queue.addLast((neighbor, dist + 1))

  -1

method test(self: GraphPathBFS): int64 =
  int64(bfsShortestPath(self.graph, 0, self.graph.vertices - 1))

registerBenchmark("GraphPathBFS", newGraphPathBFS)

proc newGraphPathDFS(): Benchmark =
  GraphPathDFS()

method name(self: GraphPathDFS): string = "GraphPathDFS"

proc dfsFindPath(g: Graph, start, target: int): int =
  if start == target:
    return 0

  var visited = newSeq[bool](g.vertices)
  var stack: seq[(int, int)] = @[(start, 0)]
  var bestPath = high(int)

  while stack.len > 0:
    let (v, dist) = stack.pop()

    if visited[v] or dist >= bestPath:
      continue

    visited[v] = true

    for neighbor in g.adj[v]:
      if neighbor == target:
        if dist + 1 < bestPath:
          bestPath = dist + 1
      elif not visited[neighbor]:
        stack.add((neighbor, dist + 1))

  if bestPath == high(int): -1 else: bestPath

method test(self: GraphPathDFS): int64 =
  int64(dfsFindPath(self.graph, 0, self.graph.vertices - 1))

registerBenchmark("GraphPathDFS", newGraphPathDFS)

type
  PriorityQueueItem = object
    vertex: int
    priority: int

  PriorityQueue = object
    vertices: seq[int]
    priorities: seq[int]
    size: int

proc newPriorityQueue(initialCapacity: int = 16): PriorityQueue =
  result.vertices = newSeq[int](initialCapacity)
  result.priorities = newSeq[int](initialCapacity)
  result.size = 0

proc push(pq: var PriorityQueue, vertex: int, priority: int) =
  if pq.size >= pq.vertices.len:
    let newCapacity = pq.vertices.len * 2
    pq.vertices.setLen(newCapacity)
    pq.priorities.setLen(newCapacity)

  var i = pq.size
  pq.size += 1
  pq.vertices[i] = vertex
  pq.priorities[i] = priority

  while i > 0:
    let parent = (i - 1) div 2
    if pq.priorities[parent] <= pq.priorities[i]:
      break
    swap(pq.vertices[i], pq.vertices[parent])
    swap(pq.priorities[i], pq.priorities[parent])
    i = parent

proc pop(pq: var PriorityQueue): int =
  result = pq.vertices[0]
  pq.size -= 1

  if pq.size > 0:
    pq.vertices[0] = pq.vertices[pq.size]
    pq.priorities[0] = pq.priorities[pq.size]

    var i = 0
    while true:
      let left = 2 * i + 1
      let right = 2 * i + 2
      var smallest = i

      if left < pq.size and pq.priorities[left] < pq.priorities[smallest]:
        smallest = left
      if right < pq.size and pq.priorities[right] < pq.priorities[smallest]:
        smallest = right
      if smallest == i:
        break

      swap(pq.vertices[i], pq.vertices[smallest])
      swap(pq.priorities[i], pq.priorities[smallest])
      i = smallest

proc isEmpty(pq: PriorityQueue): bool = pq.size == 0

proc newGraphPathAStar(): Benchmark =
  GraphPathAStar()

method name(self: GraphPathAStar): string = "GraphPathAStar"

proc heuristic(v, target: int): int = target - v

proc aStarShortestPath(g: Graph, start, target: int): int =
  if start == target:
    return 0

  let INF = high(int)
  var gScore = newSeq[int](g.vertices)
  var fScore = newSeq[int](g.vertices)
  var closed = newSeq[bool](g.vertices)

  for i in 0..<g.vertices:
    gScore[i] = INF
    fScore[i] = INF

  gScore[start] = 0
  fScore[start] = heuristic(start, target)

  var openSet = newPriorityQueue()
  var inOpenSet = newSeq[bool](g.vertices)

  openSet.push(start, fScore[start])
  inOpenSet[start] = true

  while not openSet.isEmpty:
    let current = openSet.pop()
    inOpenSet[current] = false

    if current == target:
      return gScore[current]

    closed[current] = true

    for neighbor in g.adj[current]:
      if closed[neighbor]:
        continue

      let tentativeG = gScore[current] + 1

      if tentativeG < gScore[neighbor]:
        gScore[neighbor] = tentativeG
        fScore[neighbor] = tentativeG + heuristic(neighbor, target)

        if not inOpenSet[neighbor]:
          openSet.push(neighbor, fScore[neighbor])
          inOpenSet[neighbor] = true

  -1

method test(self: GraphPathAStar): int64 =
  int64(aStarShortestPath(self.graph, 0, self.graph.vertices - 1))

registerBenchmark("GraphPathAStar", newGraphPathAStar)
