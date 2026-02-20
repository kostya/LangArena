package benchmarks

import scala.collection.mutable
import java.util.ArrayDeque
import scala.math.max

abstract class GraphPathBenchmark extends Benchmark:
  protected class Graph(val vertices: Int, val jumps: Int = 3, val jumpLen: Int = 100):
    val adj = Array.fill(vertices)(mutable.ArrayBuffer.empty[Int])

    def addEdge(u: Int, v: Int): Unit =
      adj(u) += v
      adj(v) += u

    def generateRandom(): Unit =

      var i = 1
      while i < vertices do
        addEdge(i, i - 1)
        i += 1

      var v = 0
      while v < vertices do
        val numJumps = Helper.nextInt(jumps)
        var j = 0
        while j < numJumps do
          val offset = Helper.nextInt(jumpLen) - jumpLen / 2
          val u = v + offset

          if u >= 0 && u < vertices && u != v then addEdge(v, u)
          j += 1
        v += 1

  protected var graph: Graph = _
  private var resultVal: Long = 0L

  override def prepare(): Unit =
    val verticesCount = configVal("vertices").toInt
    val jumpsCount = configVal("jumps").toInt
    val jumpLength = configVal("jump_len").toInt

    graph = Graph(verticesCount, jumpsCount, jumpLength)
    graph.generateRandom()

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
    bfsShortestPath(0, graph.vertices - 1).toLong

  override def name(): String = "GraphPathBFS"

class GraphPathDFS extends GraphPathBenchmark:
  override def name(): String = "GraphPathDFS"

  override def test(): Long =
    dfsFindPath(0, graph.vertices - 1).toLong

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
          else if !visited(neighbor) then stack.push(Array(neighbor, dist + 1))
          j += 1

    if bestPath == Int.MaxValue then -1 else bestPath

class GraphPathAStar extends GraphPathBenchmark:
  private case class Node(vertex: Int, priority: Int) extends Ordered[Node]:
    override def compare(that: Node): Int = this.priority - that.priority

  private def heuristic(v: Int, target: Int): Int = target - v

  private def aStarShortestPath(start: Int, target: Int): Int =
    if start == target then return 0

    val gScore = Array.fill(graph.vertices)(Int.MaxValue)
    val fScore = Array.fill(graph.vertices)(Int.MaxValue)
    val closed = new Array[Boolean](graph.vertices)

    gScore(start) = 0
    fScore(start) = heuristic(start, target)

    val openSet = mutable.PriorityQueue[Node]()(Ordering[Node].reverse)
    val inOpenSet = new Array[Boolean](graph.vertices)

    openSet.enqueue(Node(start, fScore(start)))
    inOpenSet(start) = true

    while openSet.nonEmpty do
      val current = openSet.dequeue()
      inOpenSet(current.vertex) = false

      if current.vertex == target then return gScore(current.vertex)

      closed(current.vertex) = true

      val neighbors = graph.adj(current.vertex)
      var i = 0
      while i < neighbors.size do
        val neighbor = neighbors(i)
        if !closed(neighbor) then
          val tentativeG = gScore(current.vertex) + 1

          if tentativeG < gScore(neighbor) then
            gScore(neighbor) = tentativeG
            fScore(neighbor) = tentativeG + heuristic(neighbor, target)

            if !inOpenSet(neighbor) then
              openSet.enqueue(Node(neighbor, fScore(neighbor)))
              inOpenSet(neighbor) = true
        i += 1

    -1

  override def test(): Long =
    aStarShortestPath(0, graph.vertices - 1).toLong

  override def name(): String = "GraphPathAStar"
