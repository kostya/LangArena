const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const Sieve = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    limit: i64,
    checksum_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Sieve {
        const limit = helper.config_i64("Etc::Sieve", "limit");

        const self = try allocator.create(Sieve);
        errdefer allocator.destroy(self);

        self.* = Sieve{
            .allocator = allocator,
            .helper = helper,
            .limit = limit,
            .checksum_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Sieve) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Sieve) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Etc::Sieve");
    }

    fn runSieve(self: *Sieve, lim: i64) !void {
        const limit = @as(usize, @intCast(lim));

        var primes = try self.allocator.alloc(u8, limit + 1);
        defer self.allocator.free(primes);

        @memset(primes, 1);
        primes[0] = 0;
        primes[1] = 0;

        const sqrt_limit_float = @sqrt(@as(f64, @floatFromInt(limit)));
        const sqrt_limit: usize = @intFromFloat(sqrt_limit_float);

        var p: usize = 2;
        while (p <= sqrt_limit) : (p += 1) {
            if (primes[p] == 1) {
                var multiple = p * p;
                while (multiple <= limit) : (multiple += p) {
                    primes[multiple] = 0;
                }
            }
        }

        var last_prime: i64 = 2;
        var count: i64 = 1;

        var n: usize = 3;
        while (n <= limit) : (n += 2) {
            if (primes[n] == 1) {
                last_prime = @as(i64, @intCast(n));
                count += 1;
            }
        }

        self.checksum_val +%= @as(u32, @intCast(last_prime + count));
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Sieve = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        self.runSieve(self.limit) catch return;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Sieve = @ptrCast(@alignCast(ptr));
        return self.checksum_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Sieve = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
