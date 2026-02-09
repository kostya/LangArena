const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GameOfLife = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: usize,
    height: usize,
    cells: []u8,           
    buffer: []u8,          
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
        const width = @as(usize, @intCast(w));
        const height = @as(usize, @intCast(h));
        const total_cells = width * height;

        const cells = try allocator.alloc(u8, total_cells);
        const buffer = try allocator.alloc(u8, total_cells);

        const self = try allocator.create(GameOfLife);
        errdefer {
            allocator.free(cells);
            allocator.free(buffer);
            allocator.destroy(self);
        }

        self.* = GameOfLife{
            .allocator = allocator,
            .helper = helper,
            .width = width,
            .height = height,
            .cells = cells,
            .buffer = buffer,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *GameOfLife) void {
        self.allocator.free(self.cells);
        self.allocator.free(self.buffer);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GameOfLife) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GameOfLife");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        const width = self.width;
        const height = self.height;

        @memset(self.cells, @intFromEnum(Cell.dead));
        @memset(self.buffer, @intFromEnum(Cell.dead));

        for (0..height) |y| {
            const y_idx = y * width;
            for (0..width) |x| {
                const idx = y_idx + x;
                if (self.helper.nextFloat(1.0) < 0.1) {
                    self.cells[idx] = @intFromEnum(Cell.alive);
                }
            }
        }
    }

    inline fn countNeighbors(cells: []const u8, width: usize, height: usize, x: usize, y: usize) u8 {

        const y_prev = if (y == 0) height - 1 else y - 1;
        const y_next = if (y == height - 1) 0 else y + 1;
        const x_prev = if (x == 0) width - 1 else x - 1;
        const x_next = if (x == width - 1) 0 else x + 1;

        var count: u8 = 0;

        var idx = y_prev * width;
        count += cells[idx + x_prev];
        count += cells[idx + x];
        count += cells[idx + x_next];

        idx = y * width;
        count += cells[idx + x_prev];
        count += cells[idx + x_next];

        idx = y_next * width;
        count += cells[idx + x_prev];
        count += cells[idx + x];
        count += cells[idx + x_next];

        return count;
    }

    fn nextGeneration(self: *GameOfLife) void {
        const width = self.width;
        const height = self.height;
        const cells = self.cells;
        const buffer = self.buffer;

        for (0..height) |y| {
            const y_idx = y * width;

            for (0..width) |x| {
                const idx = y_idx + x;

                const neighbors = countNeighbors(cells, width, height, x, y);
                const current = cells[idx];

                const next_state: u8 = if (current == @intFromEnum(Cell.alive)) blk: {
                    break :blk if (neighbors == 2 or neighbors == 3) 
                        @intFromEnum(Cell.alive) 
                    else 
                        @intFromEnum(Cell.dead);
                } else blk: {
                    break :blk if (neighbors == 3) 
                        @intFromEnum(Cell.alive) 
                    else 
                        @intFromEnum(Cell.dead);
                };

                buffer[idx] = next_state;
            }
        }

        std.mem.swap([]u8, &self.cells, &self.buffer);
    }

    fn computeHash(self: *const GameOfLife) u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;

        var hasher: u32 = FNV_OFFSET_BASIS;

        for (self.cells) |cell| {
            const alive: u32 = if (cell == @intFromEnum(Cell.alive)) 1 else 0;
            hasher ^= alive;
            hasher = hasher *% FNV_PRIME;  
        }

        return hasher;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GameOfLife = @ptrCast(@alignCast(ptr));
        self.nextGeneration();
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