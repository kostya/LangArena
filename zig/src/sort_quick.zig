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

        // Очищаем данные
        self.data.clearAndFree(allocator);
        self.result_val = 0;

        const size_val = self.helper.config_i64("SortQuick", "size");
        const size = @as(usize, @intCast(size_val));

        // Заполняем данными
        self.data.ensureTotalCapacity(allocator, size) catch return;
        self.helper.reset();

        for (0..size) |_| {
            const val = self.helper.nextInt(1_000_000);
            self.data.append(allocator, val) catch return;
        }
    }

    // Быстрая сортировка
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

    // Функция сортировки (переименована с test на testSort)
    fn testSort(self: *SortQuick, allocator: std.mem.Allocator) ![]i32 {
        // Копируем данные
        const arr = try allocator.alloc(i32, self.data.items.len);
        @memcpy(arr, self.data.items);

        // Сортируем
        if (arr.len > 0) {
            quickSort(arr, 0, @as(i32, @intCast(arr.len - 1)));
        }

        return arr;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *SortQuick = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const data = self.data.items;

        // Используем arena для временных аллокаций
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // 1. Добавляем случайный элемент из исходных данных
        if (data.len > 0) {
            const idx1 = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(data.len)))));
            self.result_val +%= @as(u32, @intCast(data[idx1]));
        }

        // 2. Сортируем и добавляем случайный элемент из отсортированных данных
        const sorted = self.testSort(arena_allocator) catch return;
        if (sorted.len > 0) {
            const idx2 = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(sorted.len)))));
            self.result_val +%= @as(u32, @intCast(sorted[idx2]));
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