// src/sort_merge.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const SortBenchmark = @import("sort_benchmark.zig").SortBenchmark;

pub const SortMerge = struct {
    base: SortBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortMerge {
        const self = try allocator.create(SortMerge);
        errdefer allocator.destroy(self);

        self.* = SortMerge{
            .base = try SortBenchmark.init(allocator, helper, "SortMerge"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *SortMerge) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortMerge) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    // ТОЧНО как в C++: merge_sort_helper
    fn mergeSortHelper(arr: []i32, temp: []i32, left: usize, right: usize) void {
        if (left >= right) return;
        
        const mid = (left + right) / 2;
        mergeSortHelper(arr, temp, left, mid);
        mergeSortHelper(arr, temp, mid + 1, right);
        merge(arr, temp, left, mid, right);
    }
    
    // ТОЧНО как в C++: merge
    fn merge(arr: []i32, temp: []i32, left: usize, mid: usize, right: usize) void {
        // Копируем как в C++: for (int i = left; i <= right; i++) temp[i] = arr[i];
        @memcpy(temp[left..right + 1], arr[left..right + 1]);
        
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

    fn runImpl(ptr: *anyopaque) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        const allocator = self.base.allocator;

        const data_len = self.base.data.items.len;
        
        // ДВА массива на ВСЮ работу (как в C++)
        const arr_buffer = allocator.alloc(i32, data_len) catch return;
        defer allocator.free(arr_buffer);
        
        const merge_temp = allocator.alloc(i32, data_len) catch return; // ОДИН раз!
        defer allocator.free(merge_temp);

        // Проверяем исходный массив (1 раз)
        const verify1 = self.base.checkNElements(self.base.data.items, 10) catch return;
        defer allocator.free(verify1);

        // Выполняем сортировку (n-1) раз
        const n_int = @as(usize, @intCast(@max(self.base.n, 0)));
        if (n_int > 0) {
            for (0..n_int - 1) |_| {
                // Копируем данные в arr_buffer
                @memcpy(arr_buffer, self.base.data.items);
                
                // Сортируем, используя ОДИН И ТОТ ЖЕ merge_temp
                // ТОЧНО как в C++: merge_sort_inplace(arr_buffer);
                mergeSortHelper(arr_buffer, merge_temp, 0, data_len - 1);
                self.base.result_val +%= @as(u64, @intCast(arr_buffer[data_len / 2]));
            }
        }

        // Финальная сортировка
        @memcpy(arr_buffer, self.base.data.items);
        mergeSortHelper(arr_buffer, merge_temp, 0, data_len - 1);
        const final_arr = arr_buffer; // Псевдоним

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
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.base.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *SortMerge = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};