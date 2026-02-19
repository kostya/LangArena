const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortSelf = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayList(i32),
    result_val: u32,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortSelf {
        const self = try allocator.create(SortSelf);
        errdefer allocator.destroy(self);

        self.* = SortSelf{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortSelf) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortSelf) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "SortSelf");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        self.data.clearAndFree(allocator);
        self.result_val = 0;

        const size_val = self.helper.config_i64("SortSelf", "size");
        const size = @as(usize, @intCast(size_val));

        self.data.ensureTotalCapacity(allocator, size) catch return;
        self.helper.reset();

        for (0..size) |_| {
            const val = self.helper.nextInt(1_000_000);
            self.data.append(allocator, val) catch return;
        }
    }

    fn testSort(self: *SortSelf, allocator: std.mem.Allocator) ![]i32 {
        const arr = try allocator.alloc(i32, self.data.items.len);
        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            std.sort.pdq(i32, arr, {}, std.sort.asc(i32));
        }

        return arr;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const data = self.data.items;

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        if (data.len > 0) {
            const idx1 = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(data.len)))));
            self.result_val +%= @as(u32, @intCast(data[idx1]));
        }

        const sorted = self.testSort(arena_allocator) catch return;
        if (sorted.len > 0) {
            const idx2 = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(sorted.len)))));
            self.result_val +%= @as(u32, @intCast(sorted[idx2]));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
