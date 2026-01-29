const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortMerge = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(i32),
    size_val: i64,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortMerge {
        const self = try allocator.create(SortMerge);
        errdefer allocator.destroy(self);

        self.* = SortMerge{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortMerge) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortMerge) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));

        if (self.size_val == 0) {
            self.size_val = self.helper.config_i64("SortMerge", "size");
            const size = @as(usize, @intCast(self.size_val));

            self.data.clearAndFree(self.allocator);
            self.data.ensureTotalCapacity(self.allocator, size) catch return;

            for (0..size) |_| {
                self.data.appendAssumeCapacity(self.helper.nextInt(1_000_000));
            }
        }
    }

    // Merge sort implementation
    fn mergeSortHelper(arr: []i32, temp: []i32, left: usize, right: usize) void {
        if (left >= right) return;

        const mid = (left + right) / 2;
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

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const size = self.data.items.len;
        if (size == 0) return;

        // Создаем копию данных и сортируем
        var arr = self.allocator.alloc(i32, size) catch return;
        defer self.allocator.free(arr);

        var temp = self.allocator.alloc(i32, size) catch return;
        defer self.allocator.free(temp);

        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            mergeSortHelper(arr, temp, 0, arr.len - 1);

            // Добавляем случайный элемент как в C++ версии
            const random_idx = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(size)))));
            self.result_val +%= @as(u32, @intCast(arr[random_idx]));
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