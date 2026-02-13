package benchmarks

class GameOfLife extends Benchmark:
  private enum Cell:
    case DEAD, ALIVE

  private class Grid(width: Int, height: Int):
    private val w = width
    private val h = height
    private val size = w * h
    private var cells = new Array[Byte](size)
    private var buffer = new Array[Byte](size)

    private def this(width: Int, height: Int, cells: Array[Byte], buffer: Array[Byte]) =
      this(width, height)
      this.cells = cells
      this.buffer = buffer

    private def index(x: Int, y: Int): Int = y * w + x

    def apply(x: Int, y: Int): Cell =
      if cells(index(x, y)) == 1.toByte then Cell.ALIVE else Cell.DEAD

    def update(x: Int, y: Int, cell: Cell): Unit =
      cells(index(x, y)) = (if cell == Cell.ALIVE then 1 else 0).toByte

    private def countNeighbors(x: Int, y: Int, cells: Array[Byte]): Int =
      val yPrev = if y == 0 then h - 1 else y - 1
      val yNext = if y == h - 1 then 0 else y + 1
      val xPrev = if x == 0 then w - 1 else x - 1
      val xNext = if x == w - 1 then 0 else x + 1

      var count = 0
      var idx = yPrev * w
      if cells(idx + xPrev) == 1.toByte then count += 1
      if cells(idx + x) == 1.toByte then count += 1
      if cells(idx + xNext) == 1.toByte then count += 1

      idx = y * w
      if cells(idx + xPrev) == 1.toByte then count += 1
      if cells(idx + xNext) == 1.toByte then count += 1

      idx = yNext * w
      if cells(idx + xPrev) == 1.toByte then count += 1
      if cells(idx + x) == 1.toByte then count += 1
      if cells(idx + xNext) == 1.toByte then count += 1

      count

    def nextGeneration(): Grid =
      val currentCells = cells
      val nextCells = buffer

      var y = 0
      while y < h do
        val yIdx = y * w
        var x = 0
        while x < w do
          val idx = yIdx + x
          val neighbors = countNeighbors(x, y, currentCells)
          val current = currentCells(idx)

          val nextState = 
            if current == 1.toByte && (neighbors == 2 || neighbors == 3) then 1.toByte
            else if current == 0.toByte && neighbors == 3 then 1.toByte
            else 0.toByte

          nextCells(idx) = nextState
          x += 1
        y += 1

      Grid(w, h, nextCells, currentCells)

    def computeHash(): Long =
      val FNV_OFFSET_BASIS = 2166136261L
      val FNV_PRIME = 16777619L

      var hasher = FNV_OFFSET_BASIS
      var i = 0
      while i < cells.length do
        val alive = if cells(i) == 1.toByte then 1L else 0L
        hasher = (hasher ^ alive) * FNV_PRIME
        i += 1

      hasher & 0xFFFFFFFFL

  private var resultVal: Long = 0L
  private val width: Int = configVal("w").toInt
  private val height: Int = configVal("h").toInt
  private var grid: Grid = _

  override def name(): String = "GameOfLife"

  override def prepare(): Unit =
    grid = Grid(width, height)

    var y = 0
    while y < height do
      var x = 0
      while x < width do
        if Helper.nextFloat() < 0.1f then
          grid(x, y) = Cell.ALIVE
        x += 1
      y += 1

  override def run(iterationId: Int): Unit =
    grid = grid.nextGeneration()

  override def checksum(): Long = grid.computeHash()