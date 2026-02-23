const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

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

fn transpose(b_mat: [][]f64, allocator: std.mem.Allocator) ![][]f64 {
    const size = b_mat.len;
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

    return b_t;
}

fn deinitMat(mat: [][]f64, allocator: std.mem.Allocator) void {
    for (mat) |row| {
        allocator.free(row);
    }
    allocator.free(mat);
}

fn matmulSequential(a: [][]f64, b: [][]f64, allocator: std.mem.Allocator) ![][]f64 {
    const n = a.len;
    const p = b[0].len;
    var b2 = try allocator.alloc([]f64, p);
    errdefer allocator.free(b2);

    for (0..p) |j| {
        b2[j] = try allocator.alloc(f64, n);
        errdefer {
            for (b2[0..j]) |row| allocator.free(row);
            allocator.free(b2);
        }
    }

    for (0..n) |i| {
        for (0..p) |j| {
            b2[j][i] = b[i][j];
        }
    }

    var c = try allocator.alloc([]f64, n);
    errdefer allocator.free(c);

    for (0..n) |i| {
        c[i] = try allocator.alloc(f64, p);
        errdefer {
            for (c[0..i]) |row| allocator.free(row);
            allocator.free(c);
        }
    }

    for (0..n) |i| {
        const ai = a[i];
        for (0..p) |j| {
            const b2j = b2[j];
            var s: f64 = 0.0;

            for (0..n) |k| {
                s += ai[k] * b2j[k];
            }
            c[i][j] = s;
        }
    }

    for (b2) |row| allocator.free(row);
    allocator.free(b2);

    return c;
}

fn matmulParallel(a_mat: [][]f64, b_mat: [][]f64, allocator: std.mem.Allocator, num_threads: usize) ![][]f64 {
    const size = a_mat.len;
    const b_t = try transpose(b_mat, allocator);
    errdefer deinitMat(b_t, allocator);

    var c_mat = try allocator.alloc([]f64, size);
    errdefer allocator.free(c_mat);

    for (0..size) |i| {
        c_mat[i] = try allocator.alloc(f64, size);
        errdefer {
            for (c_mat[0..i]) |row| allocator.free(row);
            allocator.free(c_mat);
        }
    }

    var threads = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(threads);

    const ThreadContext = struct {
        a: [][]f64,
        b_t: [][]f64,
        c: [][]f64,
        size: usize,
        num_threads: usize,
        allocator: std.mem.Allocator,
    };

    var context = ThreadContext{
        .a = a_mat,
        .b_t = b_t,
        .c = c_mat,
        .size = size,
        .num_threads = num_threads,
        .allocator = allocator,
    };

    const Worker = struct {
        fn worker(ctx: *ThreadContext, thread_id: usize) void {
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
        threads[t] = try std.Thread.spawn(.{}, Worker.worker, .{ &context, t });
    }

    for (threads) |thread| {
        thread.join();
    }

    deinitMat(b_t, allocator);

    return c_mat;
}

const MatmulBase = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,
    a: [][]f64,
    b: [][]f64,
    num_threads: usize,
    name: []const u8,
};

fn baseInit(allocator: std.mem.Allocator, helper: *Helper, name: []const u8, num_threads: usize) !MatmulBase {
    const n = helper.config_i64(name, "n");
    return MatmulBase{
        .allocator = allocator,
        .helper = helper,
        .n = n,
        .result_val = 0,
        .a = undefined,
        .b = undefined,
        .num_threads = num_threads,
        .name = name,
    };
}

fn basePrepare(base: *MatmulBase) !void {
    const n_i32 = @as(i32, @intCast(base.n));
    base.a = try matGen(n_i32, base.allocator);
    base.b = try matGen(n_i32, base.allocator);
    base.result_val = 0;
}

fn baseDeinit(base: *MatmulBase) void {
    if (base.a.len > 0) deinitMat(base.a, base.allocator);
    if (base.b.len > 0) deinitMat(base.b, base.allocator);
}

pub const Matmul1T = struct {
    base: MatmulBase,
    vtable: Benchmark.VTable,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul1T {
        const self = try allocator.create(Matmul1T);
        errdefer allocator.destroy(self);

        self.* = Matmul1T{
            .base = try baseInit(allocator, helper, "Matmul::Single", 1),
            .vtable = .{
                .prepare = prepare,
                .run = run,
                .checksum = checksum,
                .deinit = deinit,
            },
        };
        return self;
    }

    pub fn asBenchmark(self: *Matmul1T) Benchmark {
        return Benchmark.init(self, &self.vtable, self.base.helper, self.base.name);
    }

    fn prepare(ptr: *anyopaque) void {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        basePrepare(&self.base) catch {};
    }

    fn run(ptr: *anyopaque, _: i64) void {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        const n = @as(i32, @intCast(self.base.n));
        if (n <= 0) return;

        const x = matmulSequential(self.base.a, self.base.b, self.base.allocator) catch return;
        defer deinitMat(x, self.base.allocator);

        const i = n >> 1;
        const idx = @as(usize, @intCast(i));
        const result_f64 = x[idx][idx];
        self.base.result_val +%= self.base.helper.checksum_f64(result_f64);
    }

    fn checksum(ptr: *anyopaque) u32 {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        return self.base.result_val;
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        baseDeinit(&self.base);
        self.base.allocator.destroy(self);
    }
};

pub const Matmul4T = struct {
    base: MatmulBase,
    vtable: Benchmark.VTable,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul4T {
        const self = try allocator.create(Matmul4T);
        errdefer allocator.destroy(self);

        self.* = Matmul4T{
            .base = try baseInit(allocator, helper, "Matmul::T4", 4),
            .vtable = .{
                .prepare = prepare,
                .run = run,
                .checksum = checksum,
                .deinit = deinit,
            },
        };
        return self;
    }

    pub fn asBenchmark(self: *Matmul4T) Benchmark {
        return Benchmark.init(self, &self.vtable, self.base.helper, self.base.name);
    }

    fn prepare(ptr: *anyopaque) void {
        const self: *Matmul4T = @ptrCast(@alignCast(ptr));
        basePrepare(&self.base) catch {};
    }

    fn run(ptr: *anyopaque, _: i64) void {
        const self: *Matmul4T = @ptrCast(@alignCast(ptr));
        const n = @as(i32, @intCast(self.base.n));
        if (n <= 0) return;

        const x = matmulParallel(self.base.a, self.base.b, self.base.allocator, self.base.num_threads) catch return;
        defer deinitMat(x, self.base.allocator);

        const i = n >> 1;
        const idx = @as(usize, @intCast(i));
        const result_f64 = x[idx][idx];
        self.base.result_val +%= self.base.helper.checksum_f64(result_f64);
    }

    fn checksum(ptr: *anyopaque) u32 {
        const self: *Matmul4T = @ptrCast(@alignCast(ptr));
        return self.base.result_val;
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *Matmul4T = @ptrCast(@alignCast(ptr));
        baseDeinit(&self.base);
        self.base.allocator.destroy(self);
    }
};

pub const Matmul8T = struct {
    base: MatmulBase,
    vtable: Benchmark.VTable,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul8T {
        const self = try allocator.create(Matmul8T);
        errdefer allocator.destroy(self);

        self.* = Matmul8T{
            .base = try baseInit(allocator, helper, "Matmul::T8", 8),
            .vtable = .{
                .prepare = prepare,
                .run = run,
                .checksum = checksum,
                .deinit = deinit,
            },
        };
        return self;
    }

    pub fn asBenchmark(self: *Matmul8T) Benchmark {
        return Benchmark.init(self, &self.vtable, self.base.helper, self.base.name);
    }

    fn prepare(ptr: *anyopaque) void {
        const self: *Matmul8T = @ptrCast(@alignCast(ptr));
        basePrepare(&self.base) catch {};
    }

    fn run(ptr: *anyopaque, _: i64) void {
        const self: *Matmul8T = @ptrCast(@alignCast(ptr));
        const n = @as(i32, @intCast(self.base.n));
        if (n <= 0) return;

        const x = matmulParallel(self.base.a, self.base.b, self.base.allocator, self.base.num_threads) catch return;
        defer deinitMat(x, self.base.allocator);

        const i = n >> 1;
        const idx = @as(usize, @intCast(i));
        const result_f64 = x[idx][idx];
        self.base.result_val +%= self.base.helper.checksum_f64(result_f64);
    }

    fn checksum(ptr: *anyopaque) u32 {
        const self: *Matmul8T = @ptrCast(@alignCast(ptr));
        return self.base.result_val;
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *Matmul8T = @ptrCast(@alignCast(ptr));
        baseDeinit(&self.base);
        self.base.allocator.destroy(self);
    }
};

pub const Matmul16T = struct {
    base: MatmulBase,
    vtable: Benchmark.VTable,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul16T {
        const self = try allocator.create(Matmul16T);
        errdefer allocator.destroy(self);

        self.* = Matmul16T{
            .base = try baseInit(allocator, helper, "Matmul::T16", 16),
            .vtable = .{
                .prepare = prepare,
                .run = run,
                .checksum = checksum,
                .deinit = deinit,
            },
        };
        return self;
    }

    pub fn asBenchmark(self: *Matmul16T) Benchmark {
        return Benchmark.init(self, &self.vtable, self.base.helper, self.base.name);
    }

    fn prepare(ptr: *anyopaque) void {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        basePrepare(&self.base) catch {};
    }

    fn run(ptr: *anyopaque, _: i64) void {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        const n = @as(i32, @intCast(self.base.n));
        if (n <= 0) return;

        const x = matmulParallel(self.base.a, self.base.b, self.base.allocator, self.base.num_threads) catch return;
        defer deinitMat(x, self.base.allocator);

        const i = n >> 1;
        const idx = @as(usize, @intCast(i));
        const result_f64 = x[idx][idx];
        self.base.result_val +%= self.base.helper.checksum_f64(result_f64);
    }

    fn checksum(ptr: *anyopaque) u32 {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        return self.base.result_val;
    }

    fn deinit(ptr: *anyopaque) void {
        const self: *Matmul16T = @ptrCast(@alignCast(ptr));
        baseDeinit(&self.base);
        self.base.allocator.destroy(self);
    }
};
