import std/[deques]
import ../benchmark
import ../helper
import graphpath_common

type
  GraphPathBFS* = ref object of GraphPathBenchmark

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
  var total: int64 = 0

  for (start, target) in self.pairs:
    let pathLen = bfsShortestPath(self.graph, start, target)
    total += int64(pathLen)

  total

registerBenchmark("GraphPathBFS", newGraphPathBFS)