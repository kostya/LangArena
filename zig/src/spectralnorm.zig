// src/spectralnorm.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Spectralnorm = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: usize,
    result_val: u64,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Spectralnorm {
        const n_int = helper.getInputInt("Spectralnorm");
        const n = @as(usize, @intCast(if (n_int > 0) n_int else 0));

        const self = try allocator.create(Spectralnorm);
        errdefer allocator.destroy(self);

        self.* = Spectralnorm{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Spectralnorm) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Spectralnorm) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn eval_A(i: usize, j: usize) f64 {
        const i_f = @as(f64, @floatFromInt(i));
        const j_f = @as(f64, @floatFromInt(j));
        const sum = i_f + j_f;
        return 1.0 / (sum * (sum + 1.0) / 2.0 + i_f + 1.0);
    }

    fn eval_A_times_u(allocator: std.mem.Allocator, u: []const f64) ![]f64 {
        const n = u.len;
        var result = try allocator.alloc(f64, n);

        for (0..n) |i| {
            var v: f64 = 0.0;
            for (0..n) |j| {
                v += Spectralnorm.eval_A(i, j) * u[j];
            }
            result[i] = v;
        }

        return result;
    }

    fn eval_At_times_u(allocator: std.mem.Allocator, u: []const f64) ![]f64 {
        const n = u.len;
        var result = try allocator.alloc(f64, n);

        for (0..n) |i| {
            var v: f64 = 0.0;
            for (0..n) |j| {
                v += Spectralnorm.eval_A(j, i) * u[j];
            }
            result[i] = v;
        }

        return result;
    }

    fn eval_AtA_times_u(allocator: std.mem.Allocator, u: []const f64) ![]f64 {
        const a_times_u = try Spectralnorm.eval_A_times_u(allocator, u);
        defer allocator.free(a_times_u);
        return Spectralnorm.eval_At_times_u(allocator, a_times_u);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const n = self.n;

        if (n == 0) {
            self.result_val = self.helper.checksumFloat(0.0);
            return;
        }

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var u = arena_allocator.alloc(f64, n) catch return;
        var v = arena_allocator.alloc(f64, n) catch return;

        for (0..n) |i| {
            u[i] = 1.0;
            v[i] = 1.0;
        }

        for (0..10) |_| {
            const v_new = Spectralnorm.eval_AtA_times_u(arena_allocator, u) catch return;
            defer arena_allocator.free(v_new);

            const u_new = Spectralnorm.eval_AtA_times_u(arena_allocator, v_new) catch return;
            defer arena_allocator.free(u_new);

            @memcpy(v[0..n], v_new[0..n]);
            @memcpy(u[0..n], u_new[0..n]);
        }

        var vBv: f64 = 0.0;
        var vv: f64 = 0.0;

        for (0..n) |i| {
            vBv += u[i] * v[i];
            vv += v[i] * v[i];
        }

        const result = std.math.sqrt(vBv / vv);
        self.result_val = self.helper.checksumFloat(result);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
