package benchmarks

import java.util.{ArrayDeque, Deque, PriorityQueue}
import scala.collection.mutable
import scala.math

object MazeTypes {
  object CellKind {
    val WALL = 0
    val SPACE = 1
    val START = 2
    val FINISH = 3
    val BORDER = 4
    val PATH = 5

    def isWalkable(kind: Int): Boolean =
      kind == SPACE || kind == START || kind == FINISH
  }

  class Cell(val x: Int, val y: Int) {
    var kind: Int = CellKind.WALL
    val neighbors = mutable.ArrayBuffer.empty[Cell]

    def addNeighbor(cell: Cell): Unit = neighbors += cell
    def isWalkable: Boolean = CellKind.isWalkable(kind)
    def reset(): Unit = if (kind == CellKind.SPACE) kind = CellKind.WALL
  }

  class Maze(val width: Int, val height: Int) {
    val w = math.max(width, 5)
    val h = math.max(height, 5)

    val cells: Array[Array[Cell]] = Array.ofDim[Cell](h, w)

    private var _start: Cell = _
    private var _finish: Cell = _

    def start: Cell = _start
    def finish: Cell = _finish

    for (y <- 0 until h) {
      for (x <- 0 until w) {
        cells(y)(x) = new Cell(x, y)
      }
    }

    _start = cells(1)(1)
    _finish = cells(h - 2)(w - 2)
    _start.kind = CellKind.START
    _finish.kind = CellKind.FINISH

    updateNeighbors()

    def updateNeighbors(): Unit = {
      for (y <- 0 until h) {
        for (x <- 0 until w) {
          val cell = cells(y)(x)
          cell.neighbors.clear()

          if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
            cell.addNeighbor(cells(y - 1)(x))
            cell.addNeighbor(cells(y + 1)(x))
            cell.addNeighbor(cells(y)(x + 1))
            cell.addNeighbor(cells(y)(x - 1))

            for (_ <- 0 until 4) {
              val i = Helper.nextInt(4)
              val j = Helper.nextInt(4)
              if (i != j) {
                val temp = cell.neighbors(i)
                cell.neighbors(i) = cell.neighbors(j)
                cell.neighbors(j) = temp
              }
            }
          } else {
            cell.kind = CellKind.BORDER
          }
        }
      }
    }

    def reset(): Unit = {
      for (row <- cells; cell <- row) cell.reset()
      _start.kind = CellKind.START
      _finish.kind = CellKind.FINISH
    }

    def dig(startCell: Cell): Unit = {
      import scala.collection.mutable.ArrayStack

      val stack = new ArrayStack[Cell](w * h)
      stack.push(startCell)

      while (stack.nonEmpty) {
        val cell = stack.pop()

        var walkable = 0
        for (n <- cell.neighbors) {
          if (n.isWalkable) walkable += 1
        }

        if (walkable == 1) {
          cell.kind = CellKind.SPACE
          for (n <- cell.neighbors) {
            if (n.kind == CellKind.WALL) {
              stack.push(n)
            }
          }
        }
      }
    }

    def ensureOpenFinish(startCell: Cell): Unit = {
      val stack = mutable.Stack[Cell]()
      stack.push(startCell)

      while (stack.nonEmpty) {
        val cell = stack.pop()
        cell.kind = CellKind.SPACE

        val walkable = cell.neighbors.count(_.isWalkable)
        if (walkable <= 1) {
          cell.neighbors.filter(_.kind == CellKind.WALL).foreach(stack.push)
        }
      }
    }

    def generate(): Unit = {
      _start.neighbors.filter(_.kind == CellKind.WALL).foreach(dig)
      _finish.neighbors.filter(_.kind == CellKind.WALL).foreach(ensureOpenFinish)
    }

    def middleCell(): Cell = cells(h / 2)(w / 2)

    def checksum(): Long = {
      var hasher = 2166136261L
      val prime = 16777619L

      for (y <- 0 until h; x <- 0 until w) {
        if (cells(y)(x).kind == CellKind.SPACE) {
          val value = (x * y).toLong & 0xffffffffL
          hasher = ((hasher ^ value) * prime) & 0xffffffffL
        }
      }
      hasher
    }

    def printToConsole(): Unit = {
      for (y <- 0 until h) {
        for (x <- 0 until w) {
          cells(y)(x).kind match {
            case CellKind.SPACE  => print(" ")
            case CellKind.WALL   => print("\u001b[34m#\u001b[0m")
            case CellKind.BORDER => print("\u001b[31mO\u001b[0m")
            case CellKind.START  => print("\u001b[32m>\u001b[0m")
            case CellKind.FINISH => print("\u001b[32m<\u001b[0m")
            case CellKind.PATH   => print("\u001b[33m.\u001b[0m")
          }
        }
        println()
      }
      println()
    }
  }
}

class MazeGenerator extends Benchmark {
  import MazeTypes._

  private var resultVal: Long = 0L
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var maze: Maze = _

  override def name(): String = "Maze::Generator"

  override def prepare(): Unit = {
    maze = new Maze(width, height)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    maze.reset()
    maze.generate()
    resultVal = (resultVal + maze.middleCell().kind) & 0xffffffffL
  }

  override def checksum(): Long = (resultVal + maze.checksum()) & 0xffffffffL
}

class MazeBFS extends Benchmark {
  import MazeTypes._

  case class PathNode(cell: Cell, parent: Int)

  private var resultVal: Long = 0L
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var maze: Maze = _
  private var path: List[Cell] = Nil

  override def name(): String = "Maze::BFS"

  override def prepare(): Unit = {
    maze = new Maze(width, height)
    maze.generate()
    resultVal = 0L
    path = Nil
  }

  def bfs(start: Cell, target: Cell): List[Cell] = {
    if (start == target) return List(start)

    val queue = mutable.Queue[Int]()
    val visited = Array.ofDim[Boolean](height, width)
    val pathNodes = mutable.ArrayBuffer.empty[PathNode]

    visited(start.y)(start.x) = true
    pathNodes += PathNode(start, -1)
    queue.enqueue(0)

    while (queue.nonEmpty) {
      val pathId = queue.dequeue()
      val node = pathNodes(pathId)

      node.cell.neighbors.foreach { neighbor =>
        if (neighbor == target) {
          var cur = pathId
          var result = List(target)
          while (cur >= 0) {
            result = pathNodes(cur).cell :: result
            cur = pathNodes(cur).parent
          }
          return result.reverse
        }

        if (neighbor.isWalkable && !visited(neighbor.y)(neighbor.x)) {
          visited(neighbor.y)(neighbor.x) = true
          pathNodes += PathNode(neighbor, pathId)
          queue.enqueue(pathNodes.size - 1)
        }
      }
    }
    Nil
  }

  def midCellChecksum(path: List[Cell]): Long = {
    if (path.isEmpty) return 0L
    val cell = path(path.size / 2)
    ((cell.x * cell.y).toLong) & 0xffffffffL
  }

  override def run(iterationId: Int): Unit = {
    path = bfs(maze.start, maze.finish)
    resultVal = (resultVal + path.size) & 0xffffffffL
  }

  override def checksum(): Long = (resultVal + midCellChecksum(path)) & 0xffffffffL
}

class MazeAStar extends Benchmark {
  import MazeTypes._

  case class Item(priority: Int, vertex: Int) extends Ordered[Item] {
    override def compare(that: Item): Int = {
      if (priority != that.priority) priority.compare(that.priority)
      else vertex.compare(that.vertex)
    }
  }

  private var resultVal: Long = 0L
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var maze: Maze = _
  private var path: List[Cell] = Nil

  override def name(): String = "Maze::AStar"

  override def prepare(): Unit = {
    maze = new Maze(width, height)
    maze.generate()
    resultVal = 0L
    path = Nil
  }

  def heuristic(a: Cell, b: Cell): Int =
    math.abs(a.x - b.x) + math.abs(a.y - b.y)

  def idx(y: Int, x: Int): Int = y * width + x

  def astar(start: Cell, target: Cell): List[Cell] = {
    if (start == target) return List(start)

    val size = width * height
    val cameFrom = Array.fill(size)(-1)
    val gScore = Array.fill(size)(Int.MaxValue)
    val bestF = Array.fill(size)(Int.MaxValue)

    val startIdx = idx(start.y, start.x)
    val targetIdx = idx(target.y, target.x)

    val openSet = mutable.PriorityQueue.empty[Item](Ordering[Item].reverse)
    val inOpen = new Array[Boolean](size)

    gScore(startIdx) = 0
    val fStart = heuristic(start, target)
    openSet.enqueue(Item(fStart, startIdx))
    bestF(startIdx) = fStart
    inOpen(startIdx) = true

    while (openSet.nonEmpty) {
      val current = openSet.dequeue()
      val currentIdx = current.vertex
      inOpen(currentIdx) = false

      if (currentIdx == targetIdx) {
        var cur = currentIdx
        var result = List.empty[Cell]
        while (cur != -1) {
          val y = cur / width
          val x = cur % width
          result = maze.cells(y)(x) :: result
          cur = cameFrom(cur)
        }
        return result.reverse
      }

      val currentY = currentIdx / width
      val currentX = currentIdx % width
      val currentCell = maze.cells(currentY)(currentX)
      val currentG = gScore(currentIdx)

      currentCell.neighbors.foreach { neighbor =>
        if (neighbor.isWalkable) {
          val neighborIdx = idx(neighbor.y, neighbor.x)
          val tentativeG = currentG + 1

          if (tentativeG < gScore(neighborIdx)) {
            cameFrom(neighborIdx) = currentIdx
            gScore(neighborIdx) = tentativeG
            val fNew = tentativeG + heuristic(neighbor, target)

            if (fNew < bestF(neighborIdx)) {
              bestF(neighborIdx) = fNew
              openSet.enqueue(Item(fNew, neighborIdx))
              inOpen(neighborIdx) = true
            }
          }
        }
      }
    }
    Nil
  }

  def midCellChecksum(path: List[Cell]): Long = {
    if (path.isEmpty) return 0L
    val cell = path(path.size / 2)
    ((cell.x * cell.y).toLong) & 0xffffffffL
  }

  override def run(iterationId: Int): Unit = {
    path = astar(maze.start, maze.finish)
    resultVal = (resultVal + path.size) & 0xffffffffL
  }

  override def checksum(): Long = (resultVal + midCellChecksum(path)) & 0xffffffffL
}
