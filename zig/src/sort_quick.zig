const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortQuick = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortQuick {
        const self = try allocator.create(SortQuick);
        errdefer allocator.destroy(self);

        self.* = SortQuick{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortQuick) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortQuick) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "SortQuick");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        self.data.clearAndFree(allocator);
        self.result_val = 0;

        const size_val = self.helper.config_i64("SortQuick", "size");
        const size = @as(usize, @intCast(size_val));

        self.data.ensureTotalCapacity(allocator, size) catch return;
        self.helper.reset();

        for (0..size) |_| {
            const val = self.helper.nextInt(1_000_000);
            self.data.append(allocator, val) catch return;
        }
    }

    fn quickSort(arr: []i32, low: usize, high: usize) void {
        if (low >= high) return;

        const mid = (high + low) / 2;
        const pivot = arr[mid];

        var i = low;
        var j = high;

        while (i <= j) {
            while (arr[i] < pivot) i += 1;
            while (arr[j] > pivot) j -= 1;

            if (i <= j) {
                std.mem.swap(i32, &arr[i], &arr[j]);
                i += 1;
                if (j > 0) j -= 1;
            }
        }

        if (j > low) quickSort(arr, low, j);
        if (i < high) quickSort(arr, i, high);
    }

    fn testSort(self: *SortQuick, allocator: std.mem.Allocator) ![]i32 {
        const arr = try allocator.alloc(i32, self.data.items.len);
        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            quickSort(arr, 0, arr.len - 1);
        }

        return arr;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const data = self.data.items;

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        if (data.len > 0) {
            const idx = self.helper.nextInt(@as(i32, @intCast(data.len)));
            self.result_val +%= @as(u32, @intCast(data[@as(usize, @intCast(idx))]));
        }

        const sorted = self.testSort(arena_allocator) catch return;
        defer arena_allocator.free(sorted);

        if (sorted.len > 0) {
            const idx = self.helper.nextInt(@as(i32, @intCast(sorted.len)));
            self.result_val +%= @as(u32, @intCast(sorted[@as(usize, @intCast(idx))]));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
