package benchmarks

import Benchmark
import java.util.ArrayDeque
import java.util.PriorityQueue
import java.util.Queue
import kotlin.math.abs

class MazeGenerator : Benchmark() {
    object CellKind {
        const val WALL = 0
        const val SPACE = 1
        const val START = 2
        const val FINISH = 3
        const val BORDER = 4
        const val PATH = 5
    }

    class Cell(
        val x: Int,
        val y: Int,
    ) {
        var kind = CellKind.WALL
        var neighbors: Array<Cell> = emptyArray()

        fun isWalkable(): Boolean = kind == CellKind.SPACE || kind == CellKind.START || kind == CellKind.FINISH

        fun reset() {
            if (kind == CellKind.SPACE) kind = CellKind.WALL
        }
    }

    class Maze(
        val width: Int,
        val height: Int,
    ) {
        val cells = Array(height.coerceAtLeast(5)) { y -> Array(width.coerceAtLeast(5)) { x -> Cell(x, y) } }
        val start = cells[1][1]
        val finish = cells[cells.size - 2][cells[0].size - 2]

        init {
            start.kind = CellKind.START
            finish.kind = CellKind.FINISH
            updateNeighbors()
        }

        private fun updateNeighbors() {
            for (y in cells.indices) {
                for (x in cells[y].indices) {
                    val cell = cells[y][x]

                    if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
                        val neighbors =
                            arrayOf(
                                cells[y - 1][x],
                                cells[y + 1][x],
                                cells[y][x + 1],
                                cells[y][x - 1],
                            )

                        repeat(4) {
                            val i = Helper.nextInt(4)
                            val j = Helper.nextInt(4)
                            if (i != j) {
                                val tmp = neighbors[i]
                                neighbors[i] = neighbors[j]
                                neighbors[j] = tmp
                            }
                        }
                        cell.neighbors = neighbors
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

                val walkable = cell.neighbors.count { it.isWalkable() }
                if (walkable == 1) {
                    cell.kind = CellKind.SPACE

                    for (n in cell.neighbors) {
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

                val walkable = cell.neighbors.count { it.isWalkable() }
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

    private val width = configInt("w")
    private val height = configInt("h")
    private lateinit var maze: Maze
    private var resultVal = 0u

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
                .kind
                .toUInt()
    }

    override fun checksum(): UInt = resultVal + maze.checksum()
}

private fun midCellChecksum(path: List<MazeGenerator.Cell>): UInt {
    if (path.isEmpty()) return 0u
    val cell = path[path.size / 2]
    return (cell.x * cell.y).toUInt()
}

class MazeBFS : Benchmark() {
    private var resultVal: UInt = 0u
    private val width = configInt("w")
    private val height = configInt("h")
    private lateinit var maze: MazeGenerator.Maze
    private var path: List<MazeGenerator.Cell> = emptyList()

    override fun name(): String = "Maze::BFS"

    override fun prepare() {
        maze = MazeGenerator.Maze(width, height)
        maze.generate()
        resultVal = 0u
        path = emptyList()
    }

    private class PathNode(
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
                    result.reverse()
                    return result
                }

                if (neighbor.isWalkable() && !visited[neighbor.y][neighbor.x]) {
                    visited[neighbor.y][neighbor.x] = true
                    pathNodes.add(PathNode(neighbor, pathId))
                    queue.add(pathNodes.size - 1)
                }
            }
        }
        return emptyList()
    }

    override fun run(iterationId: Int) {
        path = bfs(maze.start, maze.finish)
        resultVal += path.size.toUInt()
    }

    override fun checksum(): UInt = resultVal + midCellChecksum(path)
}

class MazeAStar : Benchmark() {
    private class Item(
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
    private val width = configInt("w")
    private val height = configInt("h")
    private lateinit var maze: MazeGenerator.Maze
    private var path: List<MazeGenerator.Cell> = emptyList()

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
    ): Int = abs(a.x - b.x) + abs(a.y - b.y)

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

        gScore[startIdx] = 0
        val fStart = heuristic(start, target)
        openSet.add(Item(fStart, startIdx))
        bestF[startIdx] = fStart

        while (openSet.isNotEmpty()) {
            val item = openSet.poll()
            val currentIdx = item.vertex

            if (item.priority != bestF[currentIdx]) continue

            if (currentIdx == targetIdx) {
                val result = mutableListOf<MazeGenerator.Cell>()
                var cur = currentIdx
                while (cur != -1) {
                    val y = cur / width
                    val x = cur % width
                    result.add(maze.cells[y][x])
                    cur = cameFrom[cur]
                }
                result.reverse()
                return result
            }

            val currentY = currentIdx / width
            val currentX = currentIdx % width
            val currentCell = maze.cells[currentY][currentX]
            val currentG = gScore[currentIdx]

            for (neighbor in currentCell.neighbors) {
                if (!neighbor.isWalkable()) continue

                val neighborIdx = idx(neighbor.y, neighbor.x)
                val tentativeG = currentG + 1

                if (tentativeG < gScore[neighborIdx]) {
                    cameFrom[neighborIdx] = currentIdx
                    gScore[neighborIdx] = tentativeG
                    val fNew = tentativeG + heuristic(neighbor, target)

                    if (fNew < bestF[neighborIdx]) {
                        bestF[neighborIdx] = fNew
                        openSet.add(Item(fNew, neighborIdx))
                    }
                }
            }
        }
        return emptyList()
    }

    override fun run(iterationId: Int) {
        path = astar(maze.start, maze.finish)
        resultVal += path.size.toUInt()
    }

    override fun checksum(): UInt = resultVal + midCellChecksum(path)
}
