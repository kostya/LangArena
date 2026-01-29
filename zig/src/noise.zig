const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const Noise = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    result_val: u32,

    const Vec2 = struct {
        x: f64,
        y: f64,
    };

    const Noise2DContext = struct {
        rgradients: std.ArrayListUnmanaged(Vec2),
        permutations: std.ArrayListUnmanaged(i32),

        fn init(allocator: std.mem.Allocator, helper: *Helper, size: i64) !Noise2DContext {
            const size_int = @as(usize, @intCast(size));
            var self = Noise2DContext{
                .rgradients = .{},
                .permutations = .{},
            };

            try self.rgradients.ensureTotalCapacity(allocator, size_int);
            try self.permutations.ensureTotalCapacity(allocator, size_int);

            // Инициализируем случайные градиенты
            for (0..size_int) |i| {
                const v = helper.nextFloat(math.pi * 2.0);
                self.rgradients.appendAssumeCapacity(Vec2{
                    .x = @cos(v),
                    .y = @sin(v),
                });
                self.permutations.appendAssumeCapacity(@as(i32, @intCast(i)));
            }

            // Перемешиваем permutations
            for (0..size_int) |i| {
                _ = i;
                const a = @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(size_int)))));
                const b = @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(size_int)))));
                std.mem.swap(i32, &self.permutations.items[a], &self.permutations.items[b]);
            }

            return self;
        }

        fn deinit(self: *Noise2DContext, allocator: std.mem.Allocator) void {
            self.rgradients.deinit(allocator);
            self.permutations.deinit(allocator);
        }

        fn getGradient(self: *const Noise2DContext, x: i32, y: i32) Vec2 {
            const size_mask = @as(usize, @intCast(self.permutations.items.len - 1));
            const idx_x = @as(usize, @intCast(x)) & size_mask;
            const idx_y = @as(usize, @intCast(y)) & size_mask;
            const sum = self.permutations.items[idx_x] + self.permutations.items[idx_y];
            const idx = @as(usize, @intCast(sum)) & size_mask;
            return self.rgradients.items[idx];
        }

        fn get(self: *const Noise2DContext, x: f64, y: f64) f64 {
            const x0f = @floor(x);
            const y0f = @floor(y);
            const x0 = @as(i32, @intFromFloat(x0f));
            const y0 = @as(i32, @intFromFloat(y0f));
            const x1 = x0 + 1;
            const y1 = y0 + 1;

            const g00 = self.getGradient(x0, y0);
            const g10 = self.getGradient(x1, y0);
            const g01 = self.getGradient(x0, y1);
            const g11 = self.getGradient(x1, y1);

            const dx0 = x - x0f;
            const dx1 = x - (x0f + 1.0);
            const dy0 = y - y0f;
            const dy1 = y - (y0f + 1.0);

            const n00 = g00.x * dx0 + g00.y * dy0;
            const n10 = g10.x * dx1 + g10.y * dy0;
            const n01 = g01.x * dx0 + g01.y * dy1;
            const n11 = g11.x * dx1 + g11.y * dy1;

            const sx = smooth(dx0);
            const sy = smooth(dy0);

            const nx0 = lerp(n00, n10, sx);
            const nx1 = lerp(n01, n11, sy);

            return lerp(nx0, nx1, sy);
        }
    };

    const SYM = [6]u32{ ' ', 0x2591, 0x2592, 0x2593, 0x2588, 0x2588 }; // ░▒▓█

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    // Вспомогательные функции
    fn lerp(a: f64, b: f64, v: f64) f64 {
        return a * (1.0 - v) + b * v;
    }

    fn smooth(v: f64) f64 {
        return v * v * (3.0 - 2.0 * v);
    }

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Noise {
        const size_val = helper.config_i64("Noise", "size");

        const self = try allocator.create(Noise);
        errdefer allocator.destroy(self);

        self.* = Noise{
            .allocator = allocator,
            .helper = helper,
            .size_val = size_val,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Noise) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Noise) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Noise = @ptrCast(@alignCast(ptr));
        const size = @as(usize, @intCast(self.size_val));

        if (size == 0) {
            return;
        }

        // Создаем контекст шума
        var n2d = Noise2DContext.init(self.allocator, self.helper, self.size_val) catch return;
        defer n2d.deinit(self.allocator);

        // Вычисляем значения для текущей итерации
        const y_offset: f64 = @as(f64, @floatFromInt(iteration_id * 128));

        for (0..size) |y| {
            for (0..size) |x| {
                const v = n2d.get(@as(f64, @floatFromInt(x)) * 0.1, (@as(f64, @floatFromInt(y)) + y_offset) * 0.1) * 0.5 + 0.5;
                var idx = @as(usize, @intFromFloat(v / 0.2));
                if (idx >= SYM.len) idx = SYM.len - 1;
                self.result_val += SYM[idx];
            }
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Noise = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Noise = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};