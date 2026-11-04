from helper import Helper
from benchmark import Benchmark, Config
from std.collections import BinaryHeap

comptime MAZE_WALL = 0
comptime MAZE_SPACE = 1
comptime MAZE_START = 2
comptime MAZE_FINISH = 3
comptime MAZE_BORDER = 4


struct _MazeCell(Copyable):
    var kind: Int
    var x: Int
    var y: Int
    var neighbors: Array[Tuple[Int, Int], 4]
    var neighbor_count: Int

    def __init__(out self, x: Int, y: Int):
        self.kind = MAZE_WALL
        self.x = x
        self.y = y
        self.neighbors = Array[Tuple[Int, Int], 4](fill=(0, 0))
        self.neighbor_count = 0

    def is_walkable(self) -> Bool:
        return (
            self.kind == MAZE_SPACE
            or self.kind == MAZE_START
            or self.kind == MAZE_FINISH
        )

    def reset(mut self):
        if self.kind == MAZE_SPACE:
            self.kind = MAZE_WALL


struct AStarEntry(Comparable, Copyable):
    var priority: Int
    var vertex: Int

    def __init__(out self, priority: Int, vertex: Int):
        self.priority = priority
        self.vertex = vertex

    def __lt__(self, other: Self) -> Bool:
        if self.priority != other.priority:
            return self.priority > other.priority
        return self.vertex < other.vertex

    def __eq__(self, other: Self) -> Bool:
        return self.priority == other.priority and self.vertex == other.vertex


struct MazeGenerator(Benchmark):
    var w: Int
    var h: Int
    var cells: List[List[_MazeCell]]
    var start_x: Int
    var start_y: Int
    var finish_x: Int
    var finish_y: Int
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.w = config.get_i64("Maze::Generator", "w")
        self.h = config.get_i64("Maze::Generator", "h")

        if self.w < 5:
            self.w = 5
        if self.h < 5:
            self.h = 5

        self.start_x = 1
        self.start_y = 1
        self.finish_x = self.w - 2
        self.finish_y = self.h - 2
        self.cells = List[List[_MazeCell]]()
        self.result = 0

    def class_name(self) -> String:
        return "Maze::Generator"

    def prepare(mut self, mut helper: Helper) raises:
        self.cells = List[List[_MazeCell]]()
        for y in range(self.h):
            var row = List[_MazeCell](capacity=self.w)
            for x in range(self.w):
                row.append(_MazeCell(x, y))
            self.cells.append(row^)

        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

        self._link_neighbors(helper)
        self.result = 0

    def _link_neighbors(mut self, mut helper: Helper):
        for y in range(self.h):
            for x in range(self.w):
                ref cell = self.cells[y][x]

                if x == 0 or y == 0 or x == self.w - 1 or y == self.h - 1:
                    cell.kind = MAZE_BORDER
                else:
                    cell.neighbors[0] = (y - 1, x)
                    cell.neighbors[1] = (y + 1, x)
                    cell.neighbors[2] = (y, x + 1)
                    cell.neighbors[3] = (y, x - 1)
                    cell.neighbor_count = 4

                    for _ in range(4):
                        var i = helper.next_int(4)
                        var j = helper.next_int(4)
                        if i != j:
                            var tmp = cell.neighbors[i]
                            cell.neighbors[i] = cell.neighbors[j]
                            cell.neighbors[j] = tmp

        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self._reset()
        self._generate()
        var mid_y = self.h >> 1
        var mid_x = self.w >> 1
        self.result += UInt32(self.cells[mid_y][mid_x].kind)

    def checksum(self) -> UInt32:
        var hash: UInt32 = 2166136261
        var prime: UInt32 = 16777619
        for y in range(self.h):
            for x in range(self.w):
                if self.cells[y][x].kind == MAZE_SPACE:
                    var j_sq = UInt32(x * y)
                    hash = (hash ^ j_sq) * prime
        return self.result + hash

    def _reset(mut self):
        for y in range(self.h):
            for x in range(self.w):
                self.cells[y][x].reset()
        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

    def _generate(mut self):
        for i in range(4):
            var ny, nx = self.cells[self.start_y][self.start_x].neighbors[i]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._dig(ny, nx)

        for i in range(4):
            var ny, nx = self.cells[self.finish_y][self.finish_x].neighbors[i]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._ensure_open_finish(ny, nx)

    def _dig(mut self, start_y: Int, start_x: Int):
        var stack = List[Tuple[Int, Int]](capacity=self.w * self.h)
        stack.append((start_y, start_x))

        while len(stack) > 0:
            var y, x = stack.pop()

            var walkable_count = 0

            for i in range(4):
                var ny, nx = self.cells[y][x].neighbors[i]
                if self.cells[ny][nx].is_walkable():
                    walkable_count += 1

            if walkable_count != 1:
                continue

            self.cells[y][x].kind = MAZE_SPACE

            for i in range(4):
                var ny, nx = self.cells[y][x].neighbors[i]
                if self.cells[ny][nx].kind == MAZE_WALL:
                    stack.append((ny, nx))

    def _ensure_open_finish(mut self, y: Int, x: Int):
        self.cells[y][x].kind = MAZE_SPACE

        var walkable_count = 0

        for i in range(4):
            var ny, nx = self.cells[y][x].neighbors[i]
            if self.cells[ny][nx].is_walkable():
                walkable_count += 1

        if walkable_count > 1:
            return

        for i in range(4):
            var ny, nx = self.cells[y][x].neighbors[i]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._ensure_open_finish(ny, nx)


struct MazeBFS(Benchmark):
    var generator: MazeGenerator
    var result: UInt32
    var path: List[Tuple[Int, Int]]

    def __init__(out self, config: Config) raises:
        self.generator = MazeGenerator(config)
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def class_name(self) -> String:
        return "Maze::BFS"

    def prepare(mut self, mut helper: Helper) raises:
        self.generator.prepare(helper)
        self.generator._generate()
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.path = Self._bfs(
            self.generator,
            self.generator.start_x,
            self.generator.start_y,
            self.generator.finish_x,
            self.generator.finish_y,
        )
        self.result += UInt32(len(self.path))

    def checksum(self) -> UInt32:
        return self.result + Self._mid_cell_checksum(self.path)

    @staticmethod
    def _mid_cell_checksum(path: List[Tuple[Int, Int]]) -> UInt32:
        if len(path) == 0:
            return 0
        var mid = len(path) // 2
        var cell = path[mid]
        return UInt32(cell[0] * cell[1])

    @staticmethod
    def _bfs(
        maze: MazeGenerator,
        sx: Int,
        sy: Int,
        tx: Int,
        ty: Int,
    ) -> List[Tuple[Int, Int]]:
        if sx == tx and sy == ty:
            return [(sx, sy)]

        var visited = List[List[Bool]](capacity=maze.h)
        for _ in range(maze.h):
            var row = List[Bool](length=maze.w, fill=False)
            visited.append(row^)

        var queue = List[Int](capacity=maze.w * maze.h)
        var path_nodes = List[Tuple[Int, Int, Int]](capacity=maze.w * maze.h)

        visited[sy][sx] = True
        path_nodes.append((sx, sy, -1))
        queue.append(0)

        var q_idx = 0
        while q_idx < len(queue):
            var path_id = queue[q_idx]
            q_idx += 1
            var cx, cy, _ = path_nodes[path_id]

            ref cell = maze.cells[cy][cx]

            for i in range(cell.neighbor_count):
                var ny, nx = cell.neighbors[i]

                if nx == tx and ny == ty:
                    var result: List[Tuple[Int, Int]] = [(tx, ty)]
                    var current = path_id
                    while current >= 0:
                        var p = path_nodes[current]
                        result.append((p[0], p[1]))
                        current = p[2]
                    result.reverse()
                    return result^

                if maze.cells[ny][nx].is_walkable() and not visited[ny][nx]:
                    visited[ny][nx] = True
                    path_nodes.append((nx, ny, path_id))
                    queue.append(len(path_nodes) - 1)

        return List[Tuple[Int, Int]]()


struct MazeAStar(Benchmark):
    var generator: MazeGenerator
    var result: UInt32
    var path: List[Tuple[Int, Int]]

    def __init__(out self, config: Config) raises:
        self.generator = MazeGenerator(config)
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def class_name(self) -> String:
        return "Maze::AStar"

    def prepare(mut self, mut helper: Helper) raises:
        self.generator.prepare(helper)
        self.generator._generate()
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.path = Self._astar(
            self.generator,
            self.generator.start_x,
            self.generator.start_y,
            self.generator.finish_x,
            self.generator.finish_y,
        )
        self.result += UInt32(len(self.path))

    def checksum(self) -> UInt32:
        return self.result + Self._mid_cell_checksum(self.path)

    @staticmethod
    def _mid_cell_checksum(path: List[Tuple[Int, Int]]) -> UInt32:
        if len(path) == 0:
            return 0
        var mid = len(path) // 2
        var cell = path[mid]
        return UInt32(cell[0] * cell[1])

    @staticmethod
    def _heuristic(ax: Int, ay: Int, bx: Int, by: Int) -> Int:
        var dx = ax - bx
        var dy = ay - by
        if dx < 0:
            dx = -dx
        if dy < 0:
            dy = -dy
        return dx + dy

    @staticmethod
    def _astar(
        maze: MazeGenerator,
        sx: Int,
        sy: Int,
        tx: Int,
        ty: Int,
    ) -> List[Tuple[Int, Int]]:
        if sx == tx and sy == ty:
            return [(sx, sy)]

        var size = maze.w * maze.h
        var start_idx = sy * maze.w + sx
        var target_idx = ty * maze.w + tx

        var came_from = List[Int](length=size, fill=-1)
        var g_score = List[Int](length=size, fill=2147483647)
        var best_f = List[Int](length=size, fill=2147483647)

        var open_set = BinaryHeap[AStarEntry]()

        g_score[start_idx] = 0
        var f_start = MazeAStar._heuristic(sx, sy, tx, ty)
        open_set.push(AStarEntry(f_start, start_idx))
        best_f[start_idx] = f_start

        while len(open_set) > 0:
            var entry = open_set.pop()
            var current_idx = entry.vertex

            if current_idx == target_idx:
                var result = List[Tuple[Int, Int]]()
                var cur_idx = current_idx
                while cur_idx != -1:
                    var cy = cur_idx // maze.w
                    var cx = cur_idx % maze.w
                    result.append((cx, cy))
                    cur_idx = came_from[cur_idx]

                result.reverse()
                return result^

            var cy = current_idx // maze.w
            var cx = current_idx % maze.w
            var current_g = g_score[current_idx]

            ref cell = maze.cells[cy][cx]

            for i in range(cell.neighbor_count):
                var ny, nx = cell.neighbors[i]
                if not maze.cells[ny][nx].is_walkable():
                    continue

                var neighbor_idx = ny * maze.w + nx
                var tentative_g = current_g + 1

                if tentative_g < g_score[neighbor_idx]:
                    came_from[neighbor_idx] = current_idx
                    g_score[neighbor_idx] = tentative_g
                    var f_new = tentative_g + MazeAStar._heuristic(
                        nx, ny, tx, ty
                    )

                    if f_new < best_f[neighbor_idx]:
                        best_f[neighbor_idx] = f_new
                        open_set.push(AStarEntry(f_new, neighbor_idx))

        return List[Tuple[Int, Int]]()
