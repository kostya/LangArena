const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortMerge = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortMerge {
        const self = try allocator.create(SortMerge);
        errdefer allocator.destroy(self);

        self.* = SortMerge{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortMerge) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortMerge) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Sort::Merge");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        self.data.clearAndFree(allocator);
        self.result_val = 0;

        const size_val = self.helper.config_i64("Sort::Merge", "size");
        const size = @as(usize, @intCast(size_val));

        self.data.ensureTotalCapacity(allocator, size) catch return;
        self.helper.reset();

        for (0..size) |_| {
            const val = self.helper.nextInt(1_000_000);
            self.data.append(allocator, val) catch return;
        }
    }

    fn mergeSortHelper(arr: []i32, temp: []i32, left: usize, right: usize) void {
        if (left >= right) return;

        const mid = @divTrunc(left + right, 2);
        mergeSortHelper(arr, temp, left, mid);
        mergeSortHelper(arr, temp, mid + 1, right);
        merge(arr, temp, left, mid, right);
    }

    fn merge(arr: []i32, temp: []i32, left: usize, mid: usize, right: usize) void {
        @memcpy(temp[left .. right + 1], arr[left .. right + 1]);

        var i = left;
        var j = mid + 1;
        var k = left;

        while (i <= mid and j <= right) {
            if (temp[i] <= temp[j]) {
                arr[k] = temp[i];
                i += 1;
            } else {
                arr[k] = temp[j];
                j += 1;
            }
            k += 1;
        }

        while (i <= mid) {
            arr[k] = temp[i];
            i += 1;
            k += 1;
        }
    }

    fn testSort(self: *SortMerge, allocator: std.mem.Allocator) ![]i32 {
        const arr = try allocator.alloc(i32, self.data.items.len);
        const temp = try allocator.alloc(i32, self.data.items.len);
        defer allocator.free(temp);

        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            mergeSortHelper(arr, temp, 0, arr.len - 1);
        }

        return arr;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
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
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
