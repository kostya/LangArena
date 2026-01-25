// src/matmul4t.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Matmul16T = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i32,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul16T {
        const n = helper.getInputInt("Matmul16T");

        const self = try allocator.create(Matmul16T);
        errdefer allocator.destroy(self);

        self.* = Matmul16T{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Matmul16T) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Matmul16T) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn matGen(n: i32, allocator: std.mem.Allocator) ![][]f64 {
        const tmp = 1.0 / @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(n));
        const size = @as(usize, @intCast(n));

        var mat = try allocator.alloc([]f64, size);
        errdefer allocator.free(mat);

        for (0..size) |i| {
            mat[i] = try allocator.alloc(f64, size);
            errdefer {
                for (mat[0..i]) |row| allocator.free(row);
                allocator.free(mat);
            }
        }

        for (0..size) |i| {
            const i_f64 = @as(f64, @floatFromInt(@as(i32, @intCast(i))));
            for (0..size) |j| {
                const j_f64 = @as(f64, @floatFromInt(@as(i32, @intCast(j))));
                mat[i][j] = tmp * (i_f64 - j_f64) * (i_f64 + j_f64);
            }
        }

        return mat;
    }

    fn deinitMat(mat: [][]f64, allocator: std.mem.Allocator) void {
        for (mat) |row| allocator.free(row);
        allocator.free(mat);
    }

    fn matMulParallel(a_mat: [][]f64, b_mat: [][]f64, allocator: std.mem.Allocator, num_threads: usize) ![][]f64 {
        const size = a_mat.len;

        // Транспонируем b
        var b_t = try allocator.alloc([]f64, size);
        errdefer allocator.free(b_t);

        for (0..size) |j| {
            b_t[j] = try allocator.alloc(f64, size);
            errdefer {
                for (b_t[0..j]) |row| allocator.free(row);
                allocator.free(b_t);
            }
        }

        for (0..size) |i| {
            for (0..size) |j| {
                b_t[j][i] = b_mat[i][j];
            }
        }

        // Создаем результирующую матрицу c
        var c_mat = try allocator.alloc([]f64, size);
        errdefer allocator.free(c_mat);

        for (0..size) |i| {
            c_mat[i] = try allocator.alloc(f64, size);
            errdefer {
                for (c_mat[0..i]) |row| allocator.free(row);
                allocator.free(c_mat);
            }
        }

        // Многопоточное умножение
        var threads = try allocator.alloc(std.Thread, num_threads);
        defer allocator.free(threads);

        // Структура для захвата переменных
        const ThreadContext = struct {
            a: [][]f64,
            b_t: [][]f64,
            c: [][]f64,
            size: usize,
            num_threads: usize,
        };

        const context = ThreadContext{
            .a = a_mat,
            .b_t = b_t,
            .c = c_mat,
            .size = size,
            .num_threads = num_threads,
        };

        const Worker = struct {
            fn worker(ctx: ThreadContext, thread_id: usize) void {
                // Каждый поток обрабатывает каждую N-ю строку
                var i = thread_id;
                while (i < ctx.size) : (i += ctx.num_threads) {
                    const ai = ctx.a[i];
                    var ci = ctx.c[i];

                    for (0..ctx.size) |j| {
                        const b_tj = ctx.b_t[j];
                        var sum: f64 = 0.0;

                        for (0..ctx.size) |k| {
                            sum += ai[k] * b_tj[k];
                        }

                        ci[j] = sum;
                    }
                }
            }
        };

        for (0..num_threads) |t| {
            threads[t] = try std.Thread.spawn(.{}, Worker.worker, .{ context, t });
        }

        // Ждем завершения всех потоков
        for (threads) |thread| {
            thread.join();
        }

        // Освобождаем временную матрицу b_t
        for (b_t) |row| allocator.free(row);
        allocator.free(b_t);

        return c_mat;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        const n = self.n;
        if (n <= 0) return;

        const num_threads = 16; // Фиксировано для Matmul16T

        // Создаем матрицы
        const a = matGen(n, self.allocator) catch return;
        defer deinitMat(a, self.allocator);

        const b = matGen(n, self.allocator) catch return;
        defer deinitMat(b, self.allocator);

        // Умножаем параллельно
        const x = matMulParallel(a, b, self.allocator, num_threads) catch return;
        defer deinitMat(x, self.allocator);

        // Берем элемент посередине
        const i = n >> 1;
        const idx = @as(usize, @intCast(i));
        const result_f64 = x[idx][idx];

        self.result_val = self.helper.checksum_f64(result_f64);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
