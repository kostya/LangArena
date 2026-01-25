// src/game_of_life.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GameOfLife = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: u32,
    height: u32,
    iterations: u32,
    grid_current: []u8,
    grid_next: []u8,
    result_val: u32,

    const Cell = enum(u8) { dead = 0, alive = 1 };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GameOfLife {
        // В C++: width_(256), height_(256)
        const width = 256;
        const height = 256;
        const total_cells = width * height;

        const grid_current = try allocator.alloc(u8, total_cells);
        const grid_next = try allocator.alloc(u8, total_cells);

        const self = try allocator.create(GameOfLife);
        errdefer {
            allocator.free(grid_current);
            allocator.free(grid_next);
            allocator.destroy(self);
        }

        // iterations берем из helper
        const iterations_count = helper.getInputInt("GameOfLife");

        self.* = GameOfLife{
            .allocator = allocator,
            .helper = helper,
            .width = width,
            .height = height,
            .iterations = if (iterations_count > 0) @as(u32, @intCast(iterations_count)) else 100,
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
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        // Инициализация случайными клетками (10% живых)
        // ТОЧНО как в C++: if (Helper::next_float(1.0) < 0.1)
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                self.grid_current[idx] = if (self.helper.nextFloat(1.0) < 0.1)
                    @intFromEnum(Cell.alive)
                else
                    @intFromEnum(Cell.dead);
            }
        }
    }

    // Вспомогательная функция для безопасного доступа к тору
    inline fn getCellWrapped(grid: []const u8, width: u32, height: u32, x: i32, y: i32) u8 {
        var nx = @mod(@as(i64, @intCast(x)), @as(i64, @intCast(width)));
        if (nx < 0) nx += @as(i64, @intCast(width));

        var ny = @mod(@as(i64, @intCast(y)), @as(i64, @intCast(height)));
        if (ny < 0) ny += @as(i64, @intCast(height));

        const idx = @as(usize, @intCast(ny)) * width + @as(usize, @intCast(nx));
        return grid[idx];
    }

    // Оптимизированная версия подсчета соседей
    inline fn countNeighbors(grid: []const u8, width: u32, height: u32, x: u32, y: u32) u8 {
        const ix = @as(i32, @intCast(x));
        const iy = @as(i32, @intCast(y));

        var count: u8 = 0;

        // Развернутый цикл для лучшей производительности
        count += getCellWrapped(grid, width, height, ix - 1, iy - 1);
        count += getCellWrapped(grid, width, height, ix, iy - 1);
        count += getCellWrapped(grid, width, height, ix + 1, iy - 1);

        count += getCellWrapped(grid, width, height, ix - 1, iy);
        // Пропускаем центральную клетку
        count += getCellWrapped(grid, width, height, ix + 1, iy);

        count += getCellWrapped(grid, width, height, ix - 1, iy + 1);
        count += getCellWrapped(grid, width, height, ix, iy + 1);
        count += getCellWrapped(grid, width, height, ix + 1, iy + 1);

        return count;
    }

    // Основная функция симуляции
    fn simulateGeneration(self: *GameOfLife) void {
        const width = self.width;
        const height = self.height;
        const current = self.grid_current;
        const next = self.grid_next;

        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                const neighbors = countNeighbors(current, width, height, @as(u32, @intCast(x)), @as(u32, @intCast(y)));
                const current_cell = current[idx];

                var next_state: u8 = @intFromEnum(Cell.dead);

                if (current_cell == @intFromEnum(Cell.alive)) {
                    // Правила для живых клеток: 2 или 3 соседа
                    if (neighbors == 2 or neighbors == 3) {
                        next_state = @intFromEnum(Cell.alive);
                    }
                } else {
                    // Правила для мертвых клеток: ровно 3 соседа
                    if (neighbors == 3) {
                        next_state = @intFromEnum(Cell.alive);
                    }
                }

                next[idx] = next_state;
            }
        }

        // Меняем буферы местами
        std.mem.swap([]u8, &self.grid_current, &self.grid_next);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));

        // ТОЧНО как в C++: int iters = iterations();
        const iters = self.iterations;

        // Основной цикл симуляции
        for (0..iters) |_| {
            self.simulateGeneration();
        }

        // Подсчет живых клеток
        var alive_count: u32 = 0;
        for (self.grid_current) |cell| {
            alive_count += @intFromBool(cell == @intFromEnum(Cell.alive));
        }

        self.result_val = alive_count;

        // Для отладки
        // std.debug.print("GameOfLife: {} iterations, {} alive cells\n", .{iters, alive_count});
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
