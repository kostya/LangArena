const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortQuick = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortQuick {
        const self = try allocator.create(SortQuick);
        errdefer allocator.destroy(self);

        self.* = SortQuick{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortQuick) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortQuick) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));

        if (self.size_val == 0) {
            self.size_val = self.helper.config_i64("SortQuick", "size");
            const size = @as(usize, @intCast(self.size_val));

            self.data.clearAndFree(self.allocator);
            self.data.ensureTotalCapacity(self.allocator, size) catch return;

            for (0..size) |_| {
                self.data.appendAssumeCapacity(self.helper.nextInt(1_000_000));
            }
        }
    }

    fn quickSort(arr: []i32, low: i32, high: i32) void {
        if (low >= high) return;

        const mid = @divTrunc(low + high, 2);
        const pivot = arr[@as(usize, @intCast(mid))];
        var i = low;
        var j = high;

        while (i <= j) {
            while (arr[@as(usize, @intCast(i))] < pivot) i += 1;
            while (arr[@as(usize, @intCast(j))] > pivot) j -= 1;
            if (i <= j) {
                std.mem.swap(i32, &arr[@as(usize, @intCast(i))], &arr[@as(usize, @intCast(j))]);
                i += 1;
                j -= 1;
            }
        }

        quickSort(arr, low, j);
        quickSort(arr, i, high);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const size = self.data.items.len;
        if (size == 0) return;

        // Создаем копию данных и сортируем
        var arr = self.allocator.alloc(i32, size) catch return;
        defer self.allocator.free(arr);

        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            quickSort(arr, 0, @as(i32, @intCast(arr.len - 1)));

            // Добавляем случайный элемент как в C++ версии
            const random_idx = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(size)))));
            self.result_val +%= @as(u32, @intCast(arr[random_idx]));
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