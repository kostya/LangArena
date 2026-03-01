const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Jaro = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    count: usize,
    size: usize,
    pairs: []StringPair,
    result_val: u32,

    const StringPair = struct {
        s1: []u8,
        s2: []u8,
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Jaro {
        const self = try allocator.create(Jaro);
        errdefer allocator.destroy(self);

        const count = helper.config_i64("Distance::Jaro", "count");
        const size = helper.config_i64("Distance::Jaro", "size");

        self.* = Jaro{
            .allocator = allocator,
            .helper = helper,
            .count = @intCast(count),
            .size = @intCast(size),
            .pairs = &[_]StringPair{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Jaro) void {
        for (self.pairs) |pair| {
            self.allocator.free(pair.s1);
            self.allocator.free(pair.s2);
        }
        self.allocator.free(self.pairs);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Jaro) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Distance::Jaro");
    }

    fn generatePairStrings(self: *Jaro) ![]StringPair {
        const chars = "abcdefghij";

        var pairs = try self.allocator.alloc(StringPair, self.count);
        errdefer self.allocator.free(pairs);

        for (0..self.count) |i| {
            const len1 = @as(usize, @intCast(self.helper.nextInt(@intCast(self.size)) + 4));
            const len2 = @as(usize, @intCast(self.helper.nextInt(@intCast(self.size)) + 4));

            var str1 = try self.allocator.alloc(u8, len1);
            var str2 = try self.allocator.alloc(u8, len2);

            for (0..len1) |j| {
                str1[j] = chars[@as(usize, @intCast(self.helper.nextInt(10)))];
            }
            for (0..len2) |j| {
                str2[j] = chars[@as(usize, @intCast(self.helper.nextInt(10)))];
            }

            pairs[i] = StringPair{
                .s1 = str1,
                .s2 = str2,
            };
        }

        return pairs;
    }

    fn jaroCalc(s1: []const u8, s2: []const u8) f64 {
        const len1 = s1.len;
        const len2 = s2.len;

        if (len1 == 0 or len2 == 0) return 0.0;

        var match_dist: i32 = @divTrunc(@as(i32, @intCast(@max(len1, len2))), 2) - 1;
        if (match_dist < 0) match_dist = 0;
        const match_dist_usize = @as(usize, @intCast(match_dist));

        var s1_matches: [1024]bool = undefined;
        var s2_matches: [1024]bool = undefined;

        @memset(s1_matches[0..len1], false);
        @memset(s2_matches[0..len2], false);

        var matches: usize = 0;
        for (0..len1) |i| {
            const start = if (i > match_dist_usize) i - match_dist_usize else 0;
            const end = @min(len2 - 1, i + match_dist_usize);

            var j = start;
            while (j <= end) : (j += 1) {
                if (!s2_matches[j] and s1[i] == s2[j]) {
                    s1_matches[i] = true;
                    s2_matches[j] = true;
                    matches += 1;
                    break;
                }
            }
        }

        if (matches == 0) return 0.0;

        var transpositions: usize = 0;
        var k: usize = 0;
        for (0..len1) |i| {
            if (s1_matches[i]) {
                while (k < len2 and !s2_matches[k]) {
                    k += 1;
                }
                if (k < len2) {
                    if (s1[i] != s2[k]) {
                        transpositions += 1;
                    }
                    k += 1;
                }
            }
        }
        transpositions = @divTrunc(transpositions, 2);

        const m = @as(f64, @floatFromInt(matches));
        return (m / @as(f64, @floatFromInt(len1)) +
            m / @as(f64, @floatFromInt(len2)) +
            (m - @as(f64, @floatFromInt(transpositions))) / m) / 3.0;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Jaro = @ptrCast(@alignCast(ptr));
        self.pairs = self.generatePairStrings() catch return;
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Jaro = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        for (self.pairs) |pair| {
            const val = jaroCalc(pair.s1, pair.s2) * 1000.0;
            self.result_val +|= @as(u32, @intFromFloat(@floor(val)));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Jaro = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Jaro = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const NGram = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    count: usize,
    size: usize,
    pairs: []StringPair,
    result_val: u32,
    n: usize,

    const StringPair = struct {
        s1: []u8,
        s2: []u8,
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*NGram {
        const self = try allocator.create(NGram);
        errdefer allocator.destroy(self);

        const count = helper.config_i64("Distance::NGram", "count");
        const size = helper.config_i64("Distance::NGram", "size");

        self.* = NGram{
            .allocator = allocator,
            .helper = helper,
            .count = @intCast(count),
            .size = @intCast(size),
            .pairs = &[_]StringPair{},
            .result_val = 0,
            .n = 4,
        };

        return self;
    }

    pub fn deinit(self: *NGram) void {
        for (self.pairs) |pair| {
            self.allocator.free(pair.s1);
            self.allocator.free(pair.s2);
        }
        self.allocator.free(self.pairs);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *NGram) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Distance::NGram");
    }

    fn generatePairStrings(self: *NGram) ![]StringPair {
        const chars = "abcdefghij";

        var pairs = try self.allocator.alloc(StringPair, self.count);
        errdefer self.allocator.free(pairs);

        for (0..self.count) |i| {
            const len1 = @as(usize, @intCast(self.helper.nextInt(@intCast(self.size)) + 4));
            const len2 = @as(usize, @intCast(self.helper.nextInt(@intCast(self.size)) + 4));

            var str1 = try self.allocator.alloc(u8, len1);
            var str2 = try self.allocator.alloc(u8, len2);

            for (0..len1) |j| {
                str1[j] = chars[@as(usize, @intCast(self.helper.nextInt(10)))];
            }
            for (0..len2) |j| {
                str2[j] = chars[@as(usize, @intCast(self.helper.nextInt(10)))];
            }

            pairs[i] = StringPair{
                .s1 = str1,
                .s2 = str2,
            };
        }

        return pairs;
    }

    fn ngramCalc(self: *NGram, s1: []const u8, s2: []const u8) f64 {
        if (s1.len < self.n or s2.len < self.n) return 0.0;

        var grams1 = std.AutoHashMap(u32, u32).init(self.allocator);
        defer grams1.deinit();
        grams1.ensureTotalCapacity(@as(u32, @intCast(s1.len))) catch {};

        var i: usize = 0;
        while (i <= s1.len - self.n) : (i += 1) {
            const gram = (@as(u32, s1[i]) << 24) |
                (@as(u32, s1[i + 1]) << 16) |
                (@as(u32, s1[i + 2]) << 8) |
                @as(u32, s1[i + 3]);

            const result = grams1.getOrPut(gram) catch continue;
            if (result.found_existing) {
                result.value_ptr.* += 1;
            } else {
                result.value_ptr.* = 1;
            }
        }

        var grams2 = std.AutoHashMap(u32, u32).init(self.allocator);
        defer grams2.deinit();
        grams2.ensureTotalCapacity(@as(u32, @intCast(s2.len))) catch {};
        var intersection: u32 = 0;

        i = 0;
        while (i <= s2.len - self.n) : (i += 1) {
            const gram = (@as(u32, s2[i]) << 24) |
                (@as(u32, s2[i + 1]) << 16) |
                (@as(u32, s2[i + 2]) << 8) |
                @as(u32, s2[i + 3]);

            const result2 = grams2.getOrPut(gram) catch continue;
            if (result2.found_existing) {
                result2.value_ptr.* += 1;
            } else {
                result2.value_ptr.* = 1;
            }

            if (grams1.get(gram)) |count1| {
                if (result2.value_ptr.* <= count1) {
                    intersection += 1;
                }
            }
        }

        const total = @as(u32, @intCast(grams1.count())) + @as(u32, @intCast(grams2.count()));
        if (total > 0) {
            return @as(f64, @floatFromInt(intersection)) / @as(f64, @floatFromInt(total));
        }
        return 0.0;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *NGram = @ptrCast(@alignCast(ptr));
        self.pairs = self.generatePairStrings() catch return;
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *NGram = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        for (self.pairs) |pair| {
            const val = self.ngramCalc(pair.s1, pair.s2) * 1000.0;
            self.result_val +|= @as(u32, @intFromFloat(@floor(val)));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *NGram = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *NGram = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
