const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Matmul1T = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Matmul1T {
        const n = helper.config_i64("Matmul1T", "n");

        const self = try allocator.create(Matmul1T);
        errdefer allocator.destroy(self);

        self.* = Matmul1T{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Matmul1T) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Matmul1T) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Matmul1T");
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

    fn matMul(a: [][]f64, b: [][]f64, allocator: std.mem.Allocator) ![][]f64 {
        const m = a.len;
        const n = a[0].len;
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

        var c = try allocator.alloc([]f64, m);
        errdefer allocator.free(c);

        for (0..m) |i| {
            c[i] = try allocator.alloc(f64, p);
            errdefer {
                for (c[0..i]) |row| allocator.free(row);
                allocator.free(c);
            }
        }

        for (0..m) |i| {
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

    fn deinitMat(mat: [][]f64, allocator: std.mem.Allocator) void {
        for (mat) |row| allocator.free(row);
        allocator.free(mat);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));

        const n = @as(i32, @intCast(self.n));
        if (n <= 0) return;

        const a = matGen(n, self.allocator) catch return;
        defer deinitMat(a, self.allocator);

        const b = matGen(n, self.allocator) catch return;
        defer deinitMat(b, self.allocator);

        const x = matMul(a, b, self.allocator) catch return;
        defer deinitMat(x, self.allocator);

        const i = n >> 1;
        const idx = @as(usize, @intCast(i));

        const result_f64 = x[idx][idx];

        self.result_val +%= self.helper.checksum_f64(result_f64);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Matmul1T = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};