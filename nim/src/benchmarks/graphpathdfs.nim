import std/[sequtils]
import ../benchmark
import ../helper
import graphpath_common

type
  GraphPathDFS* = ref object of GraphPathBenchmark

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

  if bestPath == high(int):
    -1
  else:
    bestPath

method test(self: GraphPathDFS): int64 =
  var total: int64 = 0

  for (start, target) in self.pairs:
    let pathLen = dfsFindPath(self.graph, start, target)
    total += int64(pathLen)

  total

registerBenchmark("GraphPathDFS", newGraphPathDFS)