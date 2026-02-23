package benchmarks

class GameOfLife extends Benchmark:
  private class CellObj:
    var alive: Boolean = false
    var nextState: Boolean = false
    val neighbors = new Array[CellObj](8)
    var neighborCount: Int = 0

    def addNeighbor(cell: CellObj): Unit =
      neighbors(neighborCount) = cell
      neighborCount += 1

    def computeNextState(): Unit =
      var aliveNeighbors = 0
      var i = 0
      while i < neighborCount do
        if neighbors(i).alive then aliveNeighbors += 1
        i += 1

      nextState =
        if alive then aliveNeighbors == 2 || aliveNeighbors == 3
        else aliveNeighbors == 3

    def update(): Unit =
      alive = nextState

  private class Grid(val width: Int, val height: Int):
    private val cells = Array.ofDim[CellObj](height, width)

    for
      y <- 0 until height
      x <- 0 until width
    do cells(y)(x) = new CellObj

    for
      y <- 0 until height
      x <- 0 until width
    do
      val cell = cells(y)(x)
      for
        dy <- -1 to 1
        dx <- -1 to 1
        if !(dx == 0 && dy == 0)
      do
        val ny = (y + dy + height) % height
        val nx = (x + dx + width) % width
        cell.addNeighbor(cells(ny)(nx))

    def nextGeneration(): Unit =

      for
        y <- 0 until height
        x <- 0 until width
      do cells(y)(x).computeNextState()

      for
        y <- 0 until height
        x <- 0 until width
      do cells(y)(x).update()

    def countAlive(): Int =
      var count = 0
      for
        y <- 0 until height
        x <- 0 until width
      do if cells(y)(x).alive then count += 1
      count

    def computeHash(): Long =
      val FNV_OFFSET_BASIS = 2166136261L
      val FNV_PRIME = 16777619L

      var hasher = FNV_OFFSET_BASIS
      for
        y <- 0 until height
        x <- 0 until width
      do
        val alive = if cells(y)(x).alive then 1L else 0L
        hasher = (hasher ^ alive) * FNV_PRIME

      hasher & 0xffffffffL

    def getCells(): Array[Array[CellObj]] = cells

  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var grid: Grid = _

  override def name(): String = "Etc::GameOfLife"

  override def prepare(): Unit =
    grid = Grid(width, height)

    for
      y <- 0 until height
      x <- 0 until width
    do if Helper.nextFloat() < 0.1f then grid.getCells()(y)(x).alive = true

  override def run(iterationId: Int): Unit =
    grid.nextGeneration()

  override def checksum(): Long =
    val alive = grid.countAlive()
    (grid.computeHash() + alive) & 0xffffffffL
