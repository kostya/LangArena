import std/[random, deques, heapqueue]
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

  AStarItem* = object
    vertex: int
    priority: int

proc `<`*(a, b: AStarItem): bool =
  if a.priority != b.priority:
    a.priority < b.priority
  else:
    a.vertex < b.vertex

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

method name(self: GraphPathBFS): string = "Graph::BFS"

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

registerBenchmark("Graph::BFS", newGraphPathBFS)

proc newGraphPathDFS(): Benchmark =
  GraphPathDFS()

method name(self: GraphPathDFS): string = "Graph::DFS"

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

registerBenchmark("Graph::DFS", newGraphPathDFS)

proc newGraphPathAStar(): Benchmark =
  GraphPathAStar()

method name(self: GraphPathAStar): string = "Graph::AStar"

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

  var openSet = initHeapQueue[AStarItem]()
  var inOpenSet = newSeq[bool](g.vertices)

  openSet.push(AStarItem(vertex: start, priority: fScore[start]))
  inOpenSet[start] = true

  while openSet.len > 0:
    let current = openSet.pop()
    inOpenSet[current.vertex] = false

    if current.vertex == target:
      return gScore[current.vertex]

    closed[current.vertex] = true

    for neighbor in g.adj[current.vertex]:
      if closed[neighbor]:
        continue

      let tentativeG = gScore[current.vertex] + 1

      if tentativeG < gScore[neighbor]:
        gScore[neighbor] = tentativeG
        fScore[neighbor] = tentativeG + heuristic(neighbor, target)

        if not inOpenSet[neighbor]:
          openSet.push(AStarItem(vertex: neighbor, priority: fScore[neighbor]))
          inOpenSet[neighbor] = true

  -1

method test(self: GraphPathAStar): int64 =
  int64(aStarShortestPath(self.graph, 0, self.graph.vertices - 1))

registerBenchmark("Graph::AStar", newGraphPathAStar)
