// src/sort_self.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const SortBenchmark = @import("sort_benchmark.zig").SortBenchmark;

pub const SortSelf = struct {
    base: SortBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortSelf {
        const self = try allocator.create(SortSelf);
        errdefer allocator.destroy(self);

        self.* = SortSelf{
            .base = try SortBenchmark.init(allocator, helper, "SortSelf"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *SortSelf) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortSelf) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        const allocator = self.base.allocator;

        const data_len = self.base.data.items.len;
        
        // ОДИН временный буфер на все итерации
        const arr_buffer = allocator.alloc(i32, data_len) catch return;
        defer allocator.free(arr_buffer);

        // Проверяем исходный массив
        const verify1 = self.base.checkNElements(self.base.data.items, 10) catch return;
        defer allocator.free(verify1);

        // Выполняем сортировку (n-1) раз
        const n_int = @as(usize, @intCast(@max(self.base.n, 0)));
        if (n_int > 0) {
            for (0..n_int - 1) |_| {
                // Копируем в тот же буфер
                @memcpy(arr_buffer, self.base.data.items);

                // Используем std.sort.blockQuickSort (аналог std::sort в C++)
                std.sort.pdq(i32, arr_buffer, {}, comptime std.sort.asc(i32));
                self.base.result_val +%= @as(u64, @intCast(arr_buffer[data_len / 2]));
            }
        }

        // Финальная сортировка
        @memcpy(arr_buffer, self.base.data.items);        
        std.sort.pdq(i32, arr_buffer, {}, comptime std.sort.asc(i32));
        const final_arr = arr_buffer;

        // Проверяем что исходный массив не изменен
        const verify2 = self.base.checkNElements(self.base.data.items, 10) catch return;
        defer allocator.free(verify2);

        // Проверяем отсортированный массив
        const verify3 = self.base.checkNElements(final_arr, 10) catch return;
        defer allocator.free(verify3);

        // Объединяем все проверки
        var combined = std.ArrayList(u8){};
        defer combined.deinit(allocator);

        combined.appendSlice(allocator, verify1) catch return;
        combined.appendSlice(allocator, verify2) catch return;
        combined.appendSlice(allocator, verify3) catch return;

        // Добавляем checksum к результату
        const checksum = self.base.helper.checksumString(combined.items);
        self.base.result_val +%= @as(u64, checksum);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.base.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};