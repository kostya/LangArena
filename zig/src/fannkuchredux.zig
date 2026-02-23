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
        const n = helper.config_i64("CLBG::Fannkuchredux", "n");

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
        return Benchmark.init(self, &vtable, self.helper, "CLBG::Fannkuchredux");
    }

    pub fn fannkuchredux(n: i32) struct { checksum: i32, max_flips: i32 } {
        const n_usize: usize = @as(usize, @intCast(n));

        var perm1: [32]i32 = undefined;
        var perm: [32]i32 = undefined;
        var count: [32]i32 = undefined;

        for (0..n_usize) |i| {
            perm1[i] = @as(i32, @intCast(i));
        }
        @memset(perm[0..n_usize], 0);
        @memset(count[0..n_usize], 0);

        var max_flips: i32 = 0;
        var perm_count: i32 = 0;
        var checksum: i32 = 0;
        var r: i32 = n;

        while (true) {
            while (r > 1) {
                count[@as(usize, @intCast(r - 1))] = r;
                r -= 1;
            }

            @memcpy(perm[0..n_usize], perm1[0..n_usize]);

            var flips_count: i32 = 0;
            var k = perm[0];

            while (k != 0) {
                var i_local: i32 = 0;
                var j = k;
                while (i_local < j) {
                    const temp = perm[@as(usize, @intCast(i_local))];
                    perm[@as(usize, @intCast(i_local))] = perm[@as(usize, @intCast(j))];
                    perm[@as(usize, @intCast(j))] = temp;
                    i_local += 1;
                    j -= 1;
                }

                flips_count += 1;
                k = perm[0];
            }

            max_flips = @max(max_flips, flips_count);

            checksum += if ((perm_count & 1) == 0) flips_count else -flips_count;

            while (true) {
                if (r == n) {
                    return .{ .checksum = checksum, .max_flips = max_flips };
                }

                const perm0 = perm1[0];

                const r_usize = @as(usize, @intCast(r));
                for (0..r_usize) |i_shift| {
                    perm1[i_shift] = perm1[i_shift + 1];
                }
                perm1[r_usize] = perm0;

                count[r_usize] -= 1;
                if (count[r_usize] > 0) break;
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
