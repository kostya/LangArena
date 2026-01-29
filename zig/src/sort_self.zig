const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const SortSelf = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*SortSelf {
        const self = try allocator.create(SortSelf);
        errdefer allocator.destroy(self);

        self.* = SortSelf{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *SortSelf) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *SortSelf) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));

        if (self.size_val == 0) {
            self.size_val = self.helper.config_i64("SortSelf", "size");
            const size = @as(usize, @intCast(self.size_val));

            self.data.clearAndFree(self.allocator);
            self.data.ensureTotalCapacity(self.allocator, size) catch return;

            for (0..size) |_| {
                self.data.appendAssumeCapacity(self.helper.nextInt(1_000_000));
            }
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *SortSelf = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const size = self.data.items.len;
        if (size == 0) return;

        // Создаем копию данных и сортируем
        var arr = self.allocator.alloc(i32, size) catch return;
        defer self.allocator.free(arr);

        @memcpy(arr, self.data.items);

        if (arr.len > 0) {
            // Используем std.sort.pdq как аналог std::sort в C++
            std.sort.pdq(i32, arr, {}, comptime std.sort.asc(i32));

            // Добавляем случайный элемент как в C++ версии
            const random_idx = @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(size)))));
            self.result_val +%= @as(u32, @intCast(arr[random_idx]));
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