const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Spectralnorm = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    result_val: u32,
    u: std.ArrayListUnmanaged(f64),
    v: std.ArrayListUnmanaged(f64),

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Spectralnorm {
        const size_val = helper.config_i64("Spectralnorm", "size");

        const self = try allocator.create(Spectralnorm);
        errdefer allocator.destroy(self);

        self.* = Spectralnorm{
            .allocator = allocator,
            .helper = helper,
            .size_val = size_val,
            .result_val = 0,
            .u = .{},
            .v = .{},
        };

        return self;
    }

    pub fn deinit(self: *Spectralnorm) void {
        self.u.deinit(self.allocator);
        self.v.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Spectralnorm) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Spectralnorm");
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

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        const size = @as(usize, @intCast(self.size_val));

        // Очищаем старые данные
        self.u.clearAndFree(self.allocator);
        self.v.clearAndFree(self.allocator);

        // Инициализируем как в C++ версии
        self.u.ensureTotalCapacity(self.allocator, size) catch return;
        self.v.ensureTotalCapacity(self.allocator, size) catch return;

        for (0..size) |_| {
            self.u.appendAssumeCapacity(1.0);
            self.v.appendAssumeCapacity(1.0);
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const allocator = self.allocator;
        const size = @as(usize, @intCast(self.size_val));

        if (size == 0) {
            self.result_val = self.helper.checksumFloat(0.0);
            return;
        }

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Как в C++ версии: одна итерация power-метода
        const v_new = Spectralnorm.eval_AtA_times_u(arena_allocator, self.u.items) catch return;
        defer arena_allocator.free(v_new);

        const u_new = Spectralnorm.eval_AtA_times_u(arena_allocator, v_new) catch return;
        defer arena_allocator.free(u_new);

        // Обновляем векторы как в C++ версии
        self.u.clearRetainingCapacity();
        self.v.clearRetainingCapacity();

        for (0..size) |i| {
            self.u.appendAssumeCapacity(u_new[i]);
            self.v.appendAssumeCapacity(v_new[i]);
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));

        const size = @as(usize, @intCast(self.size_val));
        if (size == 0) {
            return self.helper.checksumFloat(0.0);
        }

        var vBv: f64 = 0.0;
        var vv: f64 = 0.0;

        for (0..size) |i| {
            vBv += self.u.items[i] * self.v.items[i];
            vv += self.v.items[i] * self.v.items[i];
        }

        const result = std.math.sqrt(vBv / vv);
        return self.helper.checksumFloat(result);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Spectralnorm = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};