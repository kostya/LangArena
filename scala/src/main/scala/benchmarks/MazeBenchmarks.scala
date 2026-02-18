package benchmarks

import java.util.{ArrayDeque, Deque}
import scala.collection.mutable

class MazeGenerator extends Benchmark:

  private final val WALL = 0
  private final val PATH = 1

  private var resultVal: Long = 0L
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var boolGrid: Array[Array[Boolean]] = _

  class Maze(val width: Int, val height: Int) {

    private val cells = Array.ofDim[Int](height, width)

    {
      var y = 0
      while (y < height) {
        var x = 0
        while (x < width) {
          cells(y)(x) = WALL
          x += 1
        }
        y += 1
      }
    }

    @inline def get(x: Int, y: Int): Int = cells(y)(x)
    @inline def set(x: Int, y: Int, cell: Int): Unit = cells(y)(x) = cell

    private def addRandomPaths(): Unit = {
      val numExtraPaths = (width * height) / 20
      var i = 0
      while (i < numExtraPaths) {
        val x = Helper.nextInt(width - 2) + 1
        val y = Helper.nextInt(height - 2) + 1

        if (get(x, y) == WALL &&
            get(x - 1, y) == WALL &&
            get(x + 1, y) == WALL &&
            get(x, y - 1) == WALL &&
            get(x, y + 1) == WALL) {
          set(x, y, PATH)
        }
        i += 1
      }
    }

    private def divide(x1: Int, y1: Int, x2: Int, y2: Int): Unit = {
      val w = x2 - x1
      val h = y2 - y1

      if (w < 2 || h < 2) return

      val widthForWall = math.max(w - 2, 0)
      val heightForWall = math.max(h - 2, 0)
      val widthForHole = math.max(w - 1, 0)
      val heightForHole = math.max(h - 1, 0)

      if (widthForWall == 0 || heightForWall == 0 || widthForHole == 0 || heightForHole == 0) return

      if (w > h) {
        val wallRange = math.max(widthForWall / 2, 1)
        val wallOffset = if (wallRange > 0) Helper.nextInt(wallRange) * 2 else 0
        val wallX = x1 + 2 + wallOffset

        val holeRange = math.max(heightForHole / 2, 1)
        val holeOffset = if (holeRange > 0) Helper.nextInt(holeRange) * 2 else 0
        val holeY = y1 + 1 + holeOffset

        if (wallX > x2 || holeY > y2) return

        var y = y1
        while (y <= y2) {
          if (y != holeY) set(wallX, y, WALL)
          y += 1
        }

        if (wallX > x1 + 1) divide(x1, y1, wallX - 1, y2)
        if (wallX + 1 < x2) divide(wallX + 1, y1, x2, y2)
      } else {
        val wallRange = math.max(heightForWall / 2, 1)
        val wallOffset = if (wallRange > 0) Helper.nextInt(wallRange) * 2 else 0
        val wallY = y1 + 2 + wallOffset

        val holeRange = math.max(widthForHole / 2, 1)
        val holeOffset = if (holeRange > 0) Helper.nextInt(holeRange) * 2 else 0
        val holeX = x1 + 1 + holeOffset

        if (wallY > y2 || holeX > x2) return

        var x = x1
        while (x <= x2) {
          if (x != holeX) set(x, wallY, WALL)
          x += 1
        }

        if (wallY > y1 + 1) divide(x1, y1, x2, wallY - 1)
        if (wallY + 1 < y2) divide(x1, wallY + 1, x2, y2)
      }
    }

    private def isConnectedImpl(startX: Int, startY: Int, goalX: Int, goalY: Int): Boolean = {
      if (startX >= width || startY >= height || goalX >= width || goalY >= height) return false

      val visited = Array.ofDim[Boolean](height, width)
      val queue: Deque[(Int, Int)] = new ArrayDeque()

      visited(startY)(startX) = true
      queue.add((startX, startY))

      while (!queue.isEmpty) {
        val (x, y) = queue.removeFirst()

        if (x == goalX && y == goalY) return true

        if (y > 0 && get(x, y - 1) == PATH && !visited(y - 1)(x)) {
          visited(y - 1)(x) = true
          queue.add((x, y - 1))
        }

        if (x + 1 < width && get(x + 1, y) == PATH && !visited(y)(x + 1)) {
          visited(y)(x + 1) = true
          queue.add((x + 1, y))
        }

        if (y + 1 < height && get(x, y + 1) == PATH && !visited(y + 1)(x)) {
          visited(y + 1)(x) = true
          queue.add((x, y + 1))
        }

        if (x > 0 && get(x - 1, y) == PATH && !visited(y)(x - 1)) {
          visited(y)(x - 1) = true
          queue.add((x - 1, y))
        }
      }
      false
    }

    def generate(): Unit = {
      if (width < 5 || height < 5) {
        var x = 0
        while (x < width) {
          set(x, height / 2, PATH)
          x += 1
        }
        return
      }
      divide(0, 0, width - 1, height - 1)
      addRandomPaths()
    }

    def isConnected(startX: Int, startY: Int, goalX: Int, goalY: Int): Boolean = 
      isConnectedImpl(startX, startY, goalX, goalY)

    def toBoolGrid(): Array[Array[Boolean]] = {
      val result = Array.ofDim[Boolean](height, width)
      var y = 0
      while (y < height) {
        var x = 0
        while (x < width) {
          result(y)(x) = cells(y)(x) == PATH
          x += 1
        }
        y += 1
      }
      result
    }
  }

  def generateWalkableMaze(width: Int, height: Int): Array[Array[Boolean]] = {
    val maze = new Maze(width, height)
    maze.generate()

    val startX = 1
    val startY = 1
    val goalX = width - 2
    val goalY = height - 2

    if (!maze.isConnected(startX, startY, goalX, goalY)) {
      var x = 0
      while (x < width) {
        var y = 0
        while (y < height) {
          if (x == 1 || y == 1 || x == width - 2 || y == height - 2) {
            maze.set(x, y, PATH)
          }
          y += 1
        }
        x += 1
      }
    }
    maze.toBoolGrid()
  }

  private def gridChecksum(grid: Array[Array[Boolean]]): Long = {
    var hasher = 2166136261L
    val prime = 16777619L

    var i = 0
    while (i < grid.length) {
      val row = grid(i)
      var j = 0
      while (j < row.length) {
        if (row(j)) {
          val jSquared = (j * j).toLong
          hasher = (hasher ^ jSquared) * prime
        }
        j += 1
      }
      i += 1
    }
    hasher & 0xFFFFFFFFL
  }

  override def name(): String = "MazeGenerator"

  override def run(iterationId: Int): Unit = {
    boolGrid = generateWalkableMaze(width, height)
  }

  override def checksum(): Long = gridChecksum(boolGrid)

class AStarPathfinder extends Benchmark:
  private case class Node(x: Int, y: Int, fScore: Int) extends Ordered[Node]:
    override def compare(that: Node): Int =
      if fScore != that.fScore then fScore.compare(that.fScore)
      else if y != that.y then y.compare(that.y)
      else x.compare(that.x)

  private class BinaryHeap:
    private val data = mutable.ArrayBuffer.empty[Node]

    def push(item: Node): Unit =
      data.append(item)
      siftUp(data.size - 1)

    def pop(): Option[Node] =
      if data.isEmpty then return None
      if data.size == 1 then Some(data.remove(0))
      else
        val result = data(0)
        data(0) = data(data.size - 1)
        data.remove(data.size - 1)
        siftDown(0)
        Some(result)

    def isEmpty(): Boolean = data.isEmpty

    private def siftUp(index: Int): Unit =
      var i = index
      while i > 0 do
        val parent = (i - 1) >> 1
        if data(i) >= data(parent) then return
        val temp = data(i)
        data(i) = data(parent)
        data(parent) = temp
        i = parent

    private def siftDown(index: Int): Unit =
      var i = index
      val size = data.size
      while true do
        val left = (i << 1) + 1
        val right = left + 1
        var smallest = i

        if left < size && data(left) < data(smallest) then smallest = left
        if right < size && data(right) < data(smallest) then smallest = right

        if smallest == i then return

        val temp = data(i)
        data(i) = data(smallest)
        data(smallest) = temp
        i = smallest

  private var resultVal: Long = 0L
  private val startX = 1
  private val startY = 1
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private val goalX: Int = width - 2
  private val goalY: Int = height - 2

  private var mazeGrid: Array[Array[Boolean]] = _

  private var gScoresCache: Array[Int] = _
  private var cameFromCache: Array[Int] = _

  private val DIRECTIONS = Array((0, -1), (1, 0), (0, 1), (-1, 0))
  private val STRAIGHT_COST = 1000

  gScoresCache = new Array[Int](width * height)
  cameFromCache = new Array[Int](width * height)

  private def distance(aX: Int, aY: Int, bX: Int, bY: Int): Int =
    math.abs(aX - bX) + math.abs(aY - bY)

  private def packCoords(x: Int, y: Int): Int = y * width + x
  private def unpackCoords(packed: Int): (Int, Int) = (packed % width, packed / width)

  private def findPath(): (Option[List[(Int, Int)]], Int) =
    val grid = mazeGrid
    val gScores = gScoresCache
    val cameFrom = cameFromCache

    java.util.Arrays.fill(gScores, Int.MaxValue)
    java.util.Arrays.fill(cameFrom, -1)

    val openSet = BinaryHeap()
    var nodesExplored = 0

    val startIdx = packCoords(startX, startY)
    gScores(startIdx) = 0
    openSet.push(Node(startX, startY, distance(startX, startY, goalX, goalY)))

    while !openSet.isEmpty() do
      openSet.pop() match
        case Some(current) =>
          nodesExplored += 1

          if current.x == goalX && current.y == goalY then
            val path = mutable.ArrayBuffer.empty[(Int, Int)]
            var x = current.x
            var y = current.y

            while x != startX || y != startY do
              path += ((x, y))
              val idx = packCoords(x, y)
              val packed = cameFrom(idx)
              if packed == -1 then return (None, nodesExplored)
              val (px, py) = unpackCoords(packed)
              x = px
              y = py

            path += ((startX, startY))
            val reversedPath = path.reverse.toList
            return (Some(reversedPath), nodesExplored)

          val currentIdx = packCoords(current.x, current.y)
          val currentG = gScores(currentIdx)

          DIRECTIONS.foreach { (dx, dy) =>
            val nx = current.x + dx
            val ny = current.y + dy

            if nx >= 0 && nx < width && ny >= 0 && ny < height && grid(ny)(nx) then
              val tentativeG = currentG + STRAIGHT_COST
              val neighborIdx = packCoords(nx, ny)

              if tentativeG < gScores(neighborIdx) then
                cameFrom(neighborIdx) = currentIdx
                gScores(neighborIdx) = tentativeG
                val fScore = tentativeG + distance(nx, ny, goalX, goalY)
                openSet.push(Node(nx, ny, fScore))
          }
        case None =>

    (None, nodesExplored)

  override def name(): String = "AStarPathfinder"

  override def prepare(): Unit =
    mazeGrid = MazeGenerator().generateWalkableMaze(width, height)

  override def run(iterationId: Int): Unit =
    val (path, nodesExplored) = findPath()

    var localResult = 0L
    localResult += (path.map(_.size).getOrElse(0)).toLong
    localResult = (localResult << 5) + nodesExplored.toLong

    resultVal += localResult

  override def checksum(): Long = resultVal & 0xFFFFFFFFL