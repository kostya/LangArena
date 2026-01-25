const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const SortBenchmark = @import("sort_benchmark.zig").SortBenchmark;

pub const SortQuick = struct {
    base: SortBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortQuick {
        const self = try allocator.create(SortQuick);
        errdefer allocator.destroy(self);

        self.* = SortQuick{
            // Используем имя бенчмарка из helper или фиксированное
            .base = try SortBenchmark.init(allocator, helper, "SortQuick"), // "SortQuick" или берем из helper
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *SortQuick) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortQuick) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
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

    fn runImpl(ptr: *anyopaque) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));

        // Проверяем исходный массив (1 раз)
        const verify1 = self.base.checkNElements(self.base.data.items, 10) catch return;
        defer self.base.allocator.free(verify1);

        // Выполняем сортировку (n-1) раз
        const n_int = @as(usize, @intCast(@max(self.base.n, 0)));
        
        // ИСПРАВЛЕНИЕ: для каждой итерации отдельная arena!
        for (0..n_int - 1) |_| {
            // НОВАЯ arena для каждой итерации
            var arena = std.heap.ArenaAllocator.init(self.base.allocator);
            defer arena.deinit(); // Освобождается ЗДЕСЬ
            
            const arena_allocator = arena.allocator();
            const arr = arena_allocator.alloc(i32, self.base.data.items.len) catch return;
            @memcpy(arr, self.base.data.items);

            if (arr.len > 0) {
                quickSort(arr, 0, @as(i32, @intCast(arr.len - 1)));
                self.base.result_val +%= @as(u64, @intCast(arr[arr.len / 2]));
            }
            // arena.deinit() освободит ВСЮ память этой итерации!
        }

        // Финальная сортировка (отдельная arena)
        var arena_final = std.heap.ArenaAllocator.init(self.base.allocator);
        defer arena_final.deinit();
        const final_allocator = arena_final.allocator();
        
        const final_arr = final_allocator.alloc(i32, self.base.data.items.len) catch return;
        @memcpy(final_arr, self.base.data.items);
        if (final_arr.len > 0) {
            quickSort(final_arr, 0, @as(i32, @intCast(final_arr.len - 1)));
        }

        // Проверки (используют self.base.allocator, не arena)
        const verify2 = self.base.checkNElements(self.base.data.items, 10) catch return;
        defer self.base.allocator.free(verify2);
        
        const verify3 = self.base.checkNElements(final_arr, 10) catch return;
        defer self.base.allocator.free(verify3);
        
        // Объединяем проверки
        var combined = std.ArrayList(u8){};
        defer combined.deinit(self.base.allocator);

        combined.appendSlice(self.base.allocator, verify1) catch return;
        combined.appendSlice(self.base.allocator, verify2) catch return;
        combined.appendSlice(self.base.allocator, verify3) catch return;

        // Checksum
        const checksum = self.base.helper.checksumString(combined.items);
        self.base.result_val +%= @as(u64, checksum);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.base.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};