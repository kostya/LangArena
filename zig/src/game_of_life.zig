const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GameOfLife = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    iterations: i32,
    grid_current: []u8,
    grid_next: []u8,
    result_val: u32,

    const Cell = enum(u8) { dead = 0, alive = 1 };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GameOfLife {
        const w = helper.config_i64("GameOfLife", "w");
        const h = helper.config_i64("GameOfLife", "h");
        const width = @as(i32, @intCast(w));
        const height = @as(i32, @intCast(h));
        const total_cells = @as(usize, @intCast(width * height));

        const grid_current = try allocator.alloc(u8, total_cells);
        const grid_next = try allocator.alloc(u8, total_cells);

        const self = try allocator.create(GameOfLife);
        errdefer {
            allocator.free(grid_current);
            allocator.free(grid_next);
            allocator.destroy(self);
        }

        self.* = GameOfLife{
            .allocator = allocator,
            .helper = helper,
            .width = width,
            .height = height,
            .iterations = 0,
            .grid_current = grid_current,
            .grid_next = grid_next,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *GameOfLife) void {
        self.allocator.free(self.grid_current);
        self.allocator.free(self.grid_next);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GameOfLife) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GameOfLife");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        // Используем Helper для генерации случайных чисел как в C++ версии
        for (0..@as(usize, @intCast(self.height))) |y| {
            for (0..@as(usize, @intCast(self.width))) |x| {
                const idx = y * @as(usize, @intCast(self.width)) + x;
                // Используем метод nextFloat из Helper, как предполагалось в оригинале
                self.grid_current[idx] = if (self.helper.nextFloat(1.0) < 0.1)
                    @intFromEnum(Cell.alive)
                else
                    @intFromEnum(Cell.dead);
            }
        }
        // Инициализируем grid_next нулями
        @memset(self.grid_next, @intFromEnum(Cell.dead));
    }

    inline fn getCellWrapped(grid: []const u8, width: i32, height: i32, x: i32, y: i32) u8 {
        // Исправляем вычисление индекса с учетом знака
        var nx = @rem(@as(i64, @intCast(x)), @as(i64, @intCast(width)));
        if (nx < 0) nx += @as(i64, @intCast(width));

        var ny = @rem(@as(i64, @intCast(y)), @as(i64, @intCast(height)));
        if (ny < 0) ny += @as(i64, @intCast(height));

        const idx = @as(usize, @intCast(ny)) * @as(usize, @intCast(width)) + @as(usize, @intCast(nx));
        return grid[idx];
    }

    inline fn countNeighbors(grid: []const u8, width: i32, height: i32, x: i32, y: i32) u8 {
        var count: u8 = 0;
        count += getCellWrapped(grid, width, height, x - 1, y - 1);
        count += getCellWrapped(grid, width, height, x, y - 1);
        count += getCellWrapped(grid, width, height, x + 1, y - 1);
        count += getCellWrapped(grid, width, height, x - 1, y);
        count += getCellWrapped(grid, width, height, x + 1, y);
        count += getCellWrapped(grid, width, height, x - 1, y + 1);
        count += getCellWrapped(grid, width, height, x, y + 1);
        count += getCellWrapped(grid, width, height, x + 1, y + 1);
        return count;
    }

    fn simulateGeneration(self: *GameOfLife) void {
        const width = self.width;
        const height = self.height;
        const current = self.grid_current;
        const next = self.grid_next;

        for (0..@as(usize, @intCast(height))) |y| {
            for (0..@as(usize, @intCast(width))) |x| {
                const idx = y * @as(usize, @intCast(width)) + x;
                const neighbors = countNeighbors(current, width, height, @as(i32, @intCast(x)), @as(i32, @intCast(y)));
                const current_cell = current[idx];

                var next_state: u8 = @intFromEnum(Cell.dead);
                if (current_cell == @intFromEnum(Cell.alive)) {
                    if (neighbors == 2 or neighbors == 3) {
                        next_state = @intFromEnum(Cell.alive);
                    }
                } else {
                    if (neighbors == 3) {
                        next_state = @intFromEnum(Cell.alive);
                    }
                }
                next[idx] = next_state;
            }
        }
        std.mem.swap([]u8, &self.grid_current, &self.grid_next);
    }

    fn computeHash(self: *const GameOfLife) u32 {
        var hasher: u32 = 2166136261;
        const prime: u32 = 16777619;
        for (self.grid_current) |cell| {
            const alive = if (cell == @intFromEnum(Cell.alive)) @as(u32, 1) else 0;
            hasher = (hasher ^ alive) *% prime;
        }
        return hasher;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        // Только симуляция, без лишнего присваивания
        self.simulateGeneration();
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        return self.computeHash();
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};