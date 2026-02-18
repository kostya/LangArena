package benchmarks

import Benchmark
import java.util.*

class MazeGenerator : Benchmark() {
    enum class CellKind(
        val value: Int,
    ) {
        WALL(0),
        SPACE(1),
        START(2),
        FINISH(3),
        BORDER(4),
        PATH(5),
        ;

        fun isWalkable(): Boolean = this in listOf(SPACE, START, FINISH)
    }

    class Cell(
        val x: Int,
        val y: Int,
    ) {
        var kind: CellKind = CellKind.WALL
        val neighbors = mutableListOf<Cell>()

        fun reset() {
            if (kind == CellKind.SPACE) kind = CellKind.WALL
        }
    }

    class Maze(
        val width: Int,
        val height: Int,
    ) {
        val cells: Array<Array<Cell>>
        val start: Cell
        val finish: Cell

        init {
            val w = width.coerceAtLeast(5)
            val h = height.coerceAtLeast(5)

            cells =
                Array(h) { y ->
                    Array(w) { x ->
                        Cell(x, y)
                    }
                }

            start = cells[1][1]
            finish = cells[h - 2][w - 2]
            start.kind = CellKind.START
            finish.kind = CellKind.FINISH
            updateNeighbors()
        }

        fun updateNeighbors() {
            for (y in cells.indices) {
                for (x in cells[y].indices) {
                    val cell = cells[y][x]
                    cell.neighbors.clear()

                    if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
                        cell.neighbors.add(cells[y - 1][x])
                        cell.neighbors.add(cells[y + 1][x])
                        cell.neighbors.add(cells[y][x + 1])
                        cell.neighbors.add(cells[y][x - 1])

                        repeat(4) {
                            val i = Helper.nextInt(4)
                            val j = Helper.nextInt(4)
                            if (i != j) {
                                Collections.swap(cell.neighbors, i, j)
                            }
                        }
                    } else {
                        cell.kind = CellKind.BORDER
                    }
                }
            }
        }

        fun reset() {
            for (row in cells) {
                for (cell in row) {
                    cell.reset()
                }
            }
            start.kind = CellKind.START
            finish.kind = CellKind.FINISH
        }

        private fun dig(startCell: Cell) {
            val stack = ArrayDeque<Cell>()
            stack.push(startCell)

            while (stack.isNotEmpty()) {
                val cell = stack.pop()

                var walkable = 0
                for (i in 0 until 4) {
                    if (cell.neighbors[i].kind.isWalkable()) walkable++
                }

                if (walkable == 1) {
                    cell.kind = CellKind.SPACE

                    for (i in 0 until 4) {
                        val n = cell.neighbors[i]
                        if (n.kind == CellKind.WALL) {
                            stack.push(n)
                        }
                    }
                }
            }
        }

        private fun ensureOpenFinish(startCell: Cell) {
            val stack = ArrayDeque<Cell>()
            stack.push(startCell)

            while (stack.isNotEmpty()) {
                val cell = stack.pop()

                cell.kind = CellKind.SPACE

                val walkable = cell.neighbors.count { it.kind.isWalkable() }
                if (walkable > 1) continue

                for (n in cell.neighbors) {
                    if (n.kind == CellKind.WALL) {
                        stack.push(n)
                    }
                }
            }
        }

        fun generate() {
            for (n in start.neighbors) {
                if (n.kind == CellKind.WALL) dig(n)
            }

            for (n in finish.neighbors) {
                if (n.kind == CellKind.WALL) ensureOpenFinish(n)
            }
        }

        fun middleCell(): Cell = cells[height / 2][width / 2]

        fun checksum(): UInt {
            var hasher = 2166136261uL
            val prime = 16777619uL

            for (y in cells.indices) {
                for (x in cells[y].indices) {
                    if (cells[y][x].kind == CellKind.SPACE) {
                        val value = (x * y).toULong()
                        hasher = (hasher xor value) * prime
                    }
                }
            }
            return hasher.toUInt()
        }
    }

    private lateinit var maze: Maze
    private var resultVal = 0u
    private val width: Int
    private val height: Int

    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
    }

    override fun name(): String = "Maze::Generator"

    override fun prepare() {
        maze = Maze(width, height)
    }

    override fun run(iterationId: Int) {
        maze.reset()
        maze.generate()
        resultVal +=
            maze
                .middleCell()
                .kind.value
                .toUInt()
    }

    override fun checksum(): UInt = resultVal + maze.checksum()
}

class MazeBFS : Benchmark() {
    private var resultVal: UInt = 0u
    private val width: Int
    private val height: Int
    private lateinit var maze: MazeGenerator.Maze
    private var path: List<MazeGenerator.Cell> = emptyList()

    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
    }

    override fun name(): String = "Maze::BFS"

    override fun prepare() {
        maze = MazeGenerator.Maze(width, height)
        maze.generate()
        resultVal = 0u
        path = emptyList()
    }

    private data class PathNode(
        val cell: MazeGenerator.Cell,
        val parent: Int,
    )

    private fun bfs(
        start: MazeGenerator.Cell,
        target: MazeGenerator.Cell,
    ): List<MazeGenerator.Cell> {
        if (start == target) return listOf(start)

        val queue: Queue<Int> = ArrayDeque()
        val visited = Array(height) { BooleanArray(width) }
        val pathNodes = mutableListOf<PathNode>()

        visited[start.y][start.x] = true
        pathNodes.add(PathNode(start, -1))
        queue.add(0)

        while (queue.isNotEmpty()) {
            val pathId = queue.remove()
            val node = pathNodes[pathId]

            for (neighbor in node.cell.neighbors) {
                if (neighbor == target) {
                    val result = mutableListOf(target)
                    var current = pathId
                    while (current >= 0) {
                        result.add(pathNodes[current].cell)
                        current = pathNodes[current].parent
                    }
                    return result.reversed()
                }

                if (neighbor.kind.isWalkable() && !visited[neighbor.y][neighbor.x]) {
                    visited[neighbor.y][neighbor.x] = true
                    pathNodes.add(PathNode(neighbor, pathId))
                    queue.add(pathNodes.size - 1)
                }
            }
        }
        return emptyList()
    }

    private fun midCellChecksum(path: List<MazeGenerator.Cell>): UInt {
        if (path.isEmpty()) return 0u
        val cell = path[path.size / 2]
        return (cell.x * cell.y).toUInt()
    }

    override fun run(iterationId: Int) {
        path = bfs(maze.start, maze.finish)
        resultVal += path.size.toUInt()
    }

    override fun checksum(): UInt = resultVal + midCellChecksum(path)
}

class MazeAStar : Benchmark() {
    private data class Item(
        val priority: Int,
        val vertex: Int,
    ) : Comparable<Item> {
        override fun compareTo(other: Item): Int =
            if (priority != other.priority) {
                priority.compareTo(other.priority)
            } else {
                vertex.compareTo(other.vertex)
            }
    }

    private var resultVal: UInt = 0u
    private val width: Int
    private val height: Int
    private lateinit var maze: MazeGenerator.Maze
    private var path: List<MazeGenerator.Cell> = emptyList()

    init {
        width = configVal("w").toInt()
        height = configVal("h").toInt()
    }

    override fun name(): String = "Maze::AStar"

    override fun prepare() {
        maze = MazeGenerator.Maze(width, height)
        maze.generate()
        resultVal = 0u
        path = emptyList()
    }

    private fun heuristic(
        a: MazeGenerator.Cell,
        b: MazeGenerator.Cell,
    ): Int = Math.abs(a.x - b.x) + Math.abs(a.y - b.y)

    private fun idx(
        y: Int,
        x: Int,
    ): Int = y * width + x

    private fun astar(
        start: MazeGenerator.Cell,
        target: MazeGenerator.Cell,
    ): List<MazeGenerator.Cell> {
        if (start == target) return listOf(start)

        val size = width * height
        val cameFrom = IntArray(size) { -1 }
        val gScore = IntArray(size) { Int.MAX_VALUE }
        val bestF = IntArray(size) { Int.MAX_VALUE }

        val startIdx = idx(start.y, start.x)
        val targetIdx = idx(target.y, target.x)

        val openSet = PriorityQueue<Item>()
        val inOpen = BooleanArray(size)

        gScore[startIdx] = 0
        val fStart = heuristic(start, target)
        openSet.add(Item(fStart, startIdx))
        bestF[startIdx] = fStart
        inOpen[startIdx] = true

        while (openSet.isNotEmpty()) {
            val (_, currentIdx) = openSet.poll()
            inOpen[currentIdx] = false

            if (currentIdx == targetIdx) {
                val result = mutableListOf<MazeGenerator.Cell>()
                var cur = currentIdx
                while (cur != -1) {
                    val y = cur / width
                    val x = cur % width
                    result.add(maze.cells[y][x])
                    cur = cameFrom[cur]
                }
                return result.reversed()
            }

            val currentY = currentIdx / width
            val currentX = currentIdx % width
            val currentCell = maze.cells[currentY][currentX]
            val currentG = gScore[currentIdx]

            for (neighbor in currentCell.neighbors) {
                if (!neighbor.kind.isWalkable()) continue

                val neighborIdx = idx(neighbor.y, neighbor.x)
                val tentativeG = currentG + 1

                if (tentativeG < gScore[neighborIdx]) {
                    cameFrom[neighborIdx] = currentIdx
                    gScore[neighborIdx] = tentativeG
                    val fNew = tentativeG + heuristic(neighbor, target)

                    if (fNew < bestF[neighborIdx]) {
                        bestF[neighborIdx] = fNew
                        openSet.add(Item(fNew, neighborIdx))
                        inOpen[neighborIdx] = true
                    }
                }
            }
        }
        return emptyList()
    }

    private fun midCellChecksum(path: List<MazeGenerator.Cell>): UInt {
        if (path.isEmpty()) return 0u
        val cell = path[path.size / 2]
        return (cell.x * cell.y).toUInt()
    }

    override fun run(iterationId: Int) {
        path = astar(maze.start, maze.finish)
        resultVal += path.size.toUInt()
    }

    override fun checksum(): UInt = resultVal + midCellChecksum(path)
}
