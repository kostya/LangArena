// src/noise.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const Noise = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n_iter: i32,
    res_val: u64,

    const SIZE: usize = 64;
    const SYM: [6]u32 = [_]u32{ ' ', 0x2591, 0x2592, 0x2593, 0x2588, 0x2588 }; // ░▒▓█

    const Vec2 = struct {
        x: f64,
        y: f64,
    };

    const Noise2DContext = struct {
        rgradients: [SIZE]Vec2,
        permutations: [SIZE]i32,

        fn init(helper: *Helper) Noise2DContext {
            var self: Noise2DContext = undefined;

            // Инициализируем случайные градиенты
            for (0..SIZE) |i| {
                const v = helper.nextFloat(math.pi * 2.0);
                self.rgradients[i] = Vec2{
                    .x = @cos(v),
                    .y = @sin(v),
                };
                self.permutations[i] = @as(i32, @intCast(i));
            }

            // Перемешиваем permutations
            for (0..SIZE) |i| {
                _ = i;
                const a = @as(usize, @intCast(helper.nextInt(SIZE)));
                const b = @as(usize, @intCast(helper.nextInt(SIZE)));
                std.mem.swap(i32, &self.permutations[a], &self.permutations[b]);
            }

            return self;
        }

        fn getGradient(self: *const Noise2DContext, x: i32, y: i32) Vec2 {
            const idx_x = @as(usize, @intCast(x)) & (SIZE - 1);
            const idx_y = @as(usize, @intCast(y)) & (SIZE - 1);
            const sum = self.permutations[idx_x] + self.permutations[idx_y];
            const idx = @as(usize, @intCast(sum)) & (SIZE - 1);
            return self.rgradients[idx];
        }

        fn get(self: *const Noise2DContext, x: f64, y: f64) f64 {
            const x0f = @floor(x);
            const y0f = @floor(y);
            const x0 = @as(i32, @intFromFloat(x0f));
            const y0 = @as(i32, @intFromFloat(y0f));
            const x1 = x0 + 1;
            const y1 = y0 + 1;

            // Получаем градиенты для 4 углов
            const g00 = self.getGradient(x0, y0);
            const g10 = self.getGradient(x1, y0);
            const g01 = self.getGradient(x0, y1);
            const g11 = self.getGradient(x1, y1);

            // Вычисляем скалярные произведения
            const dx0 = x - x0f;
            const dx1 = x - (x0f + 1.0);
            const dy0 = y - y0f;
            const dy1 = y - (y0f + 1.0);

            const n00 = g00.x * dx0 + g00.y * dy0;
            const n10 = g10.x * dx1 + g10.y * dy0;
            const n01 = g01.x * dx0 + g01.y * dy1;
            const n11 = g11.x * dx1 + g11.y * dy1;

            // Интерполяция
            const sx = smooth(dx0);
            const sy = smooth(dy0);

            const nx0 = lerp(n00, n10, sx);
            const nx1 = lerp(n01, n11, sx);

            return lerp(nx0, nx1, sy);
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
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
        const n_iter = helper.getInputInt("Noise");

        const self = try allocator.create(Noise);
        errdefer allocator.destroy(self);

        self.* = Noise{
            .allocator = allocator,
            .helper = helper,
            .n_iter = n_iter,
            .res_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Noise) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Noise) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn noiseFunc(self: *Noise) u64 {
        var pixels: [SIZE][SIZE]f64 = undefined;
        var n2d = Noise2DContext.init(self.helper);

        // Генерируем шум 100 раз
        for (0..100) |i| {
            const y_offset: f64 = @as(f64, @floatFromInt(i * 128));

            for (0..SIZE) |y| {
                for (0..SIZE) |x| {
                    const v = n2d.get(@as(f64, @floatFromInt(x)) * 0.1, (@as(f64, @floatFromInt(y)) + y_offset) * 0.1) * 0.5 + 0.5;

                    pixels[y][x] = v;
                }
            }
        }

        // Суммируем символы
        var res: u64 = 0;
        for (0..SIZE) |y| {
            for (0..SIZE) |x| {
                const v = pixels[y][x];
                var idx = @as(usize, @intFromFloat(v / 0.2));
                if (idx >= SYM.len) idx = SYM.len - 1;
                res += SYM[idx];
            }
        }

        return res;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Noise = @ptrCast(@alignCast(ptr));

        var total: u64 = 0;
        for (0..@as(usize, @intCast(self.n_iter))) |_| {
            total += self.noiseFunc();
        }

        self.res_val = total;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Noise = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.res_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Noise = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
