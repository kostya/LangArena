import std/[random, deques, sets]
import ../benchmark
import ../helper

type
  Graph* = ref object
    vertices*: int
    components*: int
    adj*: seq[seq[int]]

  GraphPathBenchmark* = ref object of Benchmark
    graph*: Graph
    pairs*: seq[(int, int)]
    nPairs*: int64
    resultVal*: uint32

proc newGraph(vertices, components: int): Graph =
  result = Graph(
    vertices: vertices,
    components: components,
    adj: newSeq[seq[int]](vertices)
  )

proc addEdge(g: Graph, u, v: int) =
  g.adj[u].add(v)
  g.adj[v].add(u)

proc generateRandom(g: Graph) =
  let componentSize = g.vertices div g.components

  for c in 0..<g.components:
    let startIdx = c * componentSize
    let endIdx = if c == g.components - 1: g.vertices else: (c + 1) * componentSize

    for i in (startIdx + 1)..<endIdx:
      let parent = startIdx + nextInt(int32(i - startIdx))
      addEdge(g, i, parent)

    let extraEdges = componentSize * 2
    for e in 0..<extraEdges:
      let u = startIdx + nextInt(int32(endIdx - startIdx))
      let v = startIdx + nextInt(int32(endIdx - startIdx))
      if u != v:
        addEdge(g, u, v)

method prepare(self: GraphPathBenchmark) =
  if self.nPairs == 0:
    self.nPairs = self.config_val("pairs")
    let vertices = int(self.config_val("vertices"))
    let comps = max(10, vertices div 10_000)

    self.graph = newGraph(vertices, comps)
    reset()
    self.graph.generateRandom()

    self.pairs = newSeq[(int, int)](self.nPairs.int)
    let componentSize = self.graph.vertices div 10

    for i in 0..<self.nPairs.int:
      if nextInt(100) < 70:

        let component = nextInt(10)
        let start = component * componentSize + nextInt(componentSize.int32)
        var e = component * componentSize + nextInt(componentSize.int32)
        while e == start:
          e = component * componentSize + nextInt(componentSize.int32)
        self.pairs[i] = (start, e)
      else:

        var c1 = nextInt(10)
        var c2 = nextInt(10)
        while c2 == c1:
          c2 = nextInt(10)
        let start = c1 * componentSize + nextInt(componentSize.int32)
        let e = c2 * componentSize + nextInt(componentSize.int32)
        self.pairs[i] = (start, e)

    self.resultVal = 0

method test*(self: GraphPathBenchmark): int64 {.base.} =
  raise newException(ValueError, "Not implemented")

method run(self: GraphPathBenchmark, iteration_id: int) =
  let total = self.test()
  self.resultVal = self.resultVal + uint32(total)

method checksum(self: GraphPathBenchmark): uint32 =
  self.resultVal