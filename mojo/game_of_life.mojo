from std.memory import Pointer
from helper import Helper
from benchmark import Benchmark, Config


struct _GOLCell(Copyable):
    var alive: Bool
    var next_state: Bool
    var neighbors: List[Pointer[_GOLCell, MutUntrackedOrigin]]

    def __init__(out self, alive: Bool = False):
        self.alive = alive
        self.next_state = False
        self.neighbors = List[Pointer[_GOLCell, MutUntrackedOrigin]](capacity=8)

    def add_neighbor(mut self, cell: Pointer[_GOLCell, MutUntrackedOrigin]):
        self.neighbors.append(cell)

    def compute_next_state(mut self):
        var alive_neighbors = 0
        for neighbor in self.neighbors:
            if neighbor[].alive:
                alive_neighbors += 1

        if self.alive:
            self.next_state = alive_neighbors == 2 or alive_neighbors == 3
        else:
            self.next_state = alive_neighbors == 3

    def update(mut self):
        self.alive = self.next_state


struct _GOLGrid:
    var width: Int
    var height: Int
    var cells: List[List[_GOLCell]]

    def __init__(out self, width: Int, height: Int):
        self.width = width
        self.height = height
        self.cells = List[List[_GOLCell]](capacity=height)

        for _ in range(height):
            var row = List[_GOLCell](capacity=width)
            for _ in range(width):
                row.append(_GOLCell(False))
            self.cells.append(row^)

        self._link_neighbors()

    def _link_neighbors(mut self):
        var cell_ptrs = List[List[Pointer[_GOLCell, MutUntrackedOrigin]]](
            capacity=self.height
        )
        for y in range(self.height):
            var row_ptrs = List[Pointer[_GOLCell, MutUntrackedOrigin]](
                capacity=self.width
            )
            for x in range(self.width):
                row_ptrs.append(
                    Pointer(to=self.cells[y][x]).unsafe_origin_cast[
                        MutUntrackedOrigin
                    ]()
                )
            cell_ptrs.append(row_ptrs^)

        for y in range(self.height):
            for x in range(self.width):
                ref cell = self.cells[y][x]

                for dy in range(-1, 2):
                    for dx in range(-1, 2):
                        if dx == 0 and dy == 0:
                            continue

                        var ny = (y + dy + self.height) % self.height
                        var nx = (x + dx + self.width) % self.width

                        cell.add_neighbor(cell_ptrs[ny][nx])

    def next_generation(mut self):
        for y in range(self.height):
            for x in range(self.width):
                self.cells[y][x].compute_next_state()

        for y in range(self.height):
            for x in range(self.width):
                self.cells[y][x].update()

    def count_alive(self) -> Int:
        var count = 0
        for y in range(self.height):
            for x in range(self.width):
                if self.cells[y][x].alive:
                    count += 1
        return count

    def compute_hash(self) -> UInt32:
        comptime FNV_OFFSET: UInt32 = 2166136261
        comptime FNV_PRIME: UInt32 = 16777619
        var hash = FNV_OFFSET

        for y in range(self.height):
            for x in range(self.width):
                var alive_val: UInt32 = 1 if self.cells[y][x].alive else 0
                hash = (hash ^ alive_val) * FNV_PRIME

        return hash


struct GameOfLife(Benchmark):
    var w: Int
    var h: Int
    var grid: _GOLGrid

    def __init__(out self, config: Config) raises:
        self.w = config.get_i64("Etc::GameOfLife", "w")
        self.h = config.get_i64("Etc::GameOfLife", "h")
        self.grid = _GOLGrid(self.w, self.h)

    def class_name(self) -> String:
        return "Etc::GameOfLife"

    def prepare(mut self, mut helper: Helper) raises:
        for y in range(self.h):
            for x in range(self.w):
                if helper.next_float(1.0) < 0.1:
                    self.grid.cells[y][x].alive = True

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.grid.next_generation()

    def checksum(mut self) -> UInt32:
        return self.grid.compute_hash() + UInt32(self.grid.count_alive())
