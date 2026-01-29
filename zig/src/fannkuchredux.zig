const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Fannkuchredux = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Fannkuchredux {
        const n = helper.config_i64("Fannkuchredux", "n");

        const self = try allocator.create(Fannkuchredux);
        errdefer allocator.destroy(self);

        self.* = Fannkuchredux{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Fannkuchredux) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Fannkuchredux) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Fannkuchredux");
    }

    inline fn fannkuchredux(n: i32) struct { checksum: i32, max_flips: i32 } {
        var perm1: [16]i32 = undefined;
        var perm: [16]i32 = undefined;
        var count: [16]i32 = undefined;

        var i: i32 = 0;
        while (i < n) : (i += 1) {
            perm1[@as(usize, @intCast(i))] = i;
            perm[@as(usize, @intCast(i))] = 0;
            count[@as(usize, @intCast(i))] = 0;
        }

        var max_flips: i32 = 0;
        var perm_count: i32 = 0;
        var checksum: i32 = 0;
        var r = n;

        while (true) {
            while (r > 1) {
                count[@as(usize, @intCast(r - 1))] = r;
                r -= 1;
            }

            i = 0;
            while (i < n) : (i += 1) {
                perm[@as(usize, @intCast(i))] = perm1[@as(usize, @intCast(i))];
            }

            var flips_count: i32 = 0;
            var k = perm[0];

            while (k != 0) {
                const k2 = (k + 1) >> 1;
                var i_local: i32 = 0;

                while (i_local < k2) : (i_local += 1) {
                    const j = k - i_local;
                    const temp = perm[@as(usize, @intCast(i_local))];
                    perm[@as(usize, @intCast(i_local))] = perm[@as(usize, @intCast(j))];
                    perm[@as(usize, @intCast(j))] = temp;
                }

                flips_count += 1;
                k = perm[0];
            }

            if (flips_count > max_flips) {
                max_flips = flips_count;
            }

            if ((perm_count & 1) == 0) {
                checksum += flips_count;
            } else {
                checksum -= flips_count;
            }

            while (true) {
                if (r == n) {
                    return .{ .checksum = checksum, .max_flips = max_flips };
                }

                const perm0 = perm1[0];
                i = 0;
                while (i < r) : (i += 1) {
                    perm1[@as(usize, @intCast(i))] = perm1[@as(usize, @intCast(i + 1))];
                }
                perm1[@as(usize, @intCast(r))] = perm0;

                count[@as(usize, @intCast(r))] -= 1;
                if (count[@as(usize, @intCast(r))] > 0) break;
                r += 1;
            }

            perm_count += 1;
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Fannkuchredux = @ptrCast(@alignCast(ptr));

        const n = @as(i32, @intCast(self.n));
        if (n <= 0 or n > 16) return;

        const result = fannkuchredux(n);
        self.result_val +%= @as(u32, @intCast(result.checksum * 100 + result.max_flips));
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Fannkuchredux = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Fannkuchredux = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};