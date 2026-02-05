import std/[algorithm]
import ../benchmark
import ../helper
import graphpath_common

type
  GraphPathDijkstra* = ref object of GraphPathBenchmark

proc newGraphPathDijkstra(): Benchmark =
  GraphPathDijkstra()

method name(self: GraphPathDijkstra): string = "GraphPathDijkstra"

const INF = 1_000_000_000

proc dijkstraShortestPath(g: Graph, start, target: int): int =
  if start == target:
    return 0

  var dist = newSeq[int](g.vertices)
  var visited = newSeq[bool](g.vertices)

  for i in 0..<g.vertices:
    dist[i] = INF
    visited[i] = false

  dist[start] = 0

  for iteration in 0..<g.vertices:
    var u = -1
    var minDist = INF

    for v in 0..<g.vertices:
      if not visited[v] and dist[v] < minDist:
        minDist = dist[v]
        u = v

    if u == -1 or minDist == INF or u == target:
      return if u == target: minDist else: -1

    visited[u] = true

    for v in g.adj[u]:
      if dist[u] + 1 < dist[v]:
        dist[v] = dist[u] + 1

  -1

method test(self: GraphPathDijkstra): int64 =
  var total: int64 = 0

  for (start, target) in self.pairs:
    let pathLen = dijkstraShortestPath(self.graph, start, target)
    total += int64(pathLen)

  total

registerBenchmark("GraphPathDijkstra", newGraphPathDijkstra)