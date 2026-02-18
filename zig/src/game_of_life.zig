const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GameOfLife = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: usize,
    height: usize,
    cells: [][]Cell,

    const Cell = struct {
        alive: bool,
        next_state: bool,
        neighbors: [8]*Cell,
        neighbor_count: usize,

        fn init() Cell {
            return Cell{
                .alive = false,
                .next_state = false,
                .neighbors = undefined,
                .neighbor_count = 0,
            };
        }

        fn addNeighbor(self: *Cell, neighbor: *Cell) void {
            self.neighbors[self.neighbor_count] = neighbor;
            self.neighbor_count += 1;
        }

        fn computeNextState(self: *Cell) void {
            var alive_neighbors: usize = 0;
            for (self.neighbors) |n| {
                if (n.alive) alive_neighbors += 1;
            }

            if (self.alive) {
                self.next_state = alive_neighbors == 2 or alive_neighbors == 3;
            } else {
                self.next_state = alive_neighbors == 3;
            }
        }

        fn update(self: *Cell) void {
            self.alive = self.next_state;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GameOfLife {
        const w = helper.config_i64("GameOfLife", "w");
        const h = helper.config_i64("GameOfLife", "h");
        const width = @as(usize, @intCast(w));
        const height = @as(usize, @intCast(h));

        var cells = try allocator.alloc([]Cell, height);
        for (0..height) |y| {
            cells[y] = try allocator.alloc(Cell, width);
            for (0..width) |x| {
                cells[y][x] = Cell.init();
            }
        }

        const self = try allocator.create(GameOfLife);
        self.* = GameOfLife{
            .allocator = allocator,
            .helper = helper,
            .width = width,
            .height = height,
            .cells = cells,
        };

        try self.linkNeighbors();
        return self;
    }

    fn linkNeighbors(self: *GameOfLife) !void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const cell = &self.cells[y][x];

                var dy: i32 = -1;
                while (dy <= 1) : (dy += 1) {
                    var dx: i32 = -1;
                    while (dx <= 1) : (dx += 1) {
                        if (dx == 0 and dy == 0) continue;

                        const ny = @mod(@as(i32, @intCast(y)) + dy + @as(i32, @intCast(self.height)), @as(i32, @intCast(self.height)));
                        const nx = @mod(@as(i32, @intCast(x)) + dx + @as(i32, @intCast(self.width)), @as(i32, @intCast(self.width)));

                        const neighbor = &self.cells[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))];
                        cell.addNeighbor(neighbor);
                    }
                }
            }
        }
    }

    fn nextGeneration(self: *GameOfLife) void {
        for (self.cells) |row| {
            for (row) |*cell| {
                cell.computeNextState();
            }
        }

        for (self.cells) |row| {
            for (row) |*cell| {
                cell.update();
            }
        }
    }

    fn countAlive(self: *const GameOfLife) u32 {
        var count: u32 = 0;
        for (self.cells) |row| {
            for (row) |cell| {
                if (cell.alive) count += 1;
            }
        }
        return count;
    }

    fn computeHash(self: *const GameOfLife) u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;

        var hash: u32 = FNV_OFFSET_BASIS;
        for (self.cells) |row| {
            for (row) |cell| {
                const alive: u32 = if (cell.alive) 1 else 0;
                hash ^= alive;
                hash *%= FNV_PRIME;
            }
        }
        return hash;
    }

    pub fn deinit(self: *GameOfLife) void {
        for (0..self.height) |y| {
            self.allocator.free(self.cells[y]);
        }
        self.allocator.free(self.cells);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GameOfLife) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GameOfLife");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        for (self.cells) |row| {
            for (row) |*cell| {
                if (self.helper.nextFloat(1.0) < 0.1) {
                    cell.alive = true;
                }
            }
        }
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        self.nextGeneration();
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        return self.computeHash() + self.countAlive();
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};