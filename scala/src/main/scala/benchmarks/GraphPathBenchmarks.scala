package benchmarks

import scala.collection.mutable
import java.util.ArrayDeque

abstract class GraphPathBenchmark extends Benchmark:
  protected class Graph(val vertices: Int, components: Int = 10):
    val adj = Array.fill(vertices)(mutable.ArrayBuffer.empty[Int])
    private val componentsCount = components

    def addEdge(u: Int, v: Int): Unit =
      adj(u) += v
      adj(v) += u

    def generateRandom(): Unit =
      val componentSize = vertices / componentsCount

      var c = 0
      while c < componentsCount do
        val startIdx = c * componentSize
        var endIdx = (c + 1) * componentSize
        if c == componentsCount - 1 then endIdx = vertices

        var i = startIdx + 1
        while i < endIdx do
          val parent = startIdx + Helper.nextInt(i - startIdx)
          addEdge(i, parent)
          i += 1

        var rep = 0
        while rep < componentSize * 2 do
          val u = startIdx + Helper.nextInt(endIdx - startIdx)
          val v = startIdx + Helper.nextInt(endIdx - startIdx)
          if u != v then addEdge(u, v)
          rep += 1

        c += 1

    def sameComponent(u: Int, v: Int): Boolean =
      val componentSize = vertices / componentsCount
      (u / componentSize) == (v / componentSize)

  protected var graph: Graph = _
  protected var pairs: Array[(Int, Int)] = _
  private var resultVal: Long = 0L
  private var nPairs: Long = 0L
  private var verticesCount: Long = 0L

  override def prepare(): Unit =
    if nPairs == 0L then
      nPairs = configVal("pairs")
      verticesCount = configVal("vertices")
      val comps = math.max(10, (verticesCount / 10000).toInt)
      graph = Graph(verticesCount.toInt, comps)
      graph.generateRandom()
      pairs = generatePairs(nPairs.toInt)

  private def generatePairs(n: Int): Array[(Int, Int)] =
    val pairsArr = new Array[(Int, Int)](n)
    val componentSize = graph.vertices / 10

    var i = 0
    while i < n do
      if Helper.nextInt(100) < 70 then

        val component = Helper.nextInt(10)
        val start = component * componentSize + Helper.nextInt(componentSize)
        var end = 0
        var found = false
        while !found do
          end = component * componentSize + Helper.nextInt(componentSize)
          if end != start then found = true
        pairsArr(i) = (start, end)
      else

        var c1 = Helper.nextInt(10)
        var c2 = Helper.nextInt(10)
        while c2 == c1 do c2 = Helper.nextInt(10)
        val start = c1 * componentSize + Helper.nextInt(componentSize)
        val end = c2 * componentSize + Helper.nextInt(componentSize)
        pairsArr(i) = (start, end)
      i += 1

    pairsArr

  def test(): Long

  override def run(iterationId: Int): Unit =
    resultVal += test()

  override def checksum(): Long = resultVal

class GraphPathBFS extends GraphPathBenchmark:
  private def bfsShortestPath(start: Int, target: Int): Int =
    if start == target then return 0

    val visited = new Array[Boolean](graph.vertices)
    val queue = ArrayDeque[(Int, Int)]()

    visited(start) = true
    queue.add((start, 0))

    while !queue.isEmpty() do
      val (v, dist) = queue.removeFirst()

      val neighbors = graph.adj(v)
      var i = 0
      while i < neighbors.size do
        val neighbor = neighbors(i)
        if neighbor == target then return dist + 1

        if !visited(neighbor) then
          visited(neighbor) = true
          queue.add((neighbor, dist + 1))
        i += 1

    -1

  override def test(): Long =
    var totalLength = 0L
    var i = 0
    while i < pairs.length do
      val (start, end) = pairs(i)
      val length = bfsShortestPath(start, end)
      totalLength += length
      i += 1
    totalLength

  override def name(): String = "GraphPathBFS"

class GraphPathDFS extends GraphPathBenchmark:
  override def name(): String = "GraphPathDFS"

  override def test(): Long =
    var totalLength = 0L
    var i = 0
    while i < pairs.length do
      val (start, end) = pairs(i)
      val length = dfsFindPath(start, end)
      totalLength += length
      i += 1
    totalLength

  private def dfsFindPath(start: Int, target: Int): Int =
    if start == target then return 0

    val visited = new Array[Boolean](graph.vertices)
    val stack = new java.util.ArrayDeque[Array[Int]]()
    var bestPath = Int.MaxValue

    stack.push(Array(start, 0))

    while !stack.isEmpty do
      val current = stack.pop()
      val v = current(0)
      val dist = current(1)

      if !visited(v) && dist < bestPath then
        visited(v) = true
        val neighbors = graph.adj(v)
        var j = 0
        while j < neighbors.size do
          val neighbor = neighbors(j)
          if neighbor == target then
            if dist + 1 < bestPath then bestPath = dist + 1
          else if !visited(neighbor) then
            stack.push(Array(neighbor, dist + 1))
          j += 1

    if bestPath == Int.MaxValue then -1 else bestPath

class GraphPathDijkstra extends GraphPathBenchmark:
  private val INF = Int.MaxValue / 2

  private def dijkstraShortestPath(start: Int, target: Int): Int =
    if start == target then return 0

    val dist = Array.fill(graph.vertices)(INF)
    val visited = new Array[Boolean](graph.vertices)

    dist(start) = 0

    var iteration = 0
    while iteration < graph.vertices do

      var u = -1
      var minDist = INF

      var v = 0
      while v < graph.vertices do
        if !visited(v) && dist(v) < minDist then
          minDist = dist(v)
          u = v
        v += 1

      if u == -1 || minDist == INF || u == target then
        return if u == target then minDist else -1

      visited(u) = true

      val neighbors = graph.adj(u)
      var i = 0
      while i < neighbors.size do
        val neighbor = neighbors(i)
        if dist(u) + 1 < dist(neighbor) then
          dist(neighbor) = dist(u) + 1
        i += 1

      iteration += 1

    -1

  override def test(): Long =
    var totalLength = 0L
    var i = 0
    while i < pairs.length do
      val (start, end) = pairs(i)
      val length = dijkstraShortestPath(start, end)
      totalLength += length
      i += 1
    totalLength

  override def name(): String = "GraphPathDijkstra"