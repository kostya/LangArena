const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const SortBenchmark = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(i32),
    n: i32,
    result_val: u64,

    const ARR_SIZE: usize = 100000;

    pub fn init(allocator: std.mem.Allocator, helper: *Helper, bench_name: []const u8) !SortBenchmark {
        var self = SortBenchmark{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .n = 0,
            .result_val = 0,
        };

        self.n = helper.getInputInt(bench_name);
        try self.data.ensureTotalCapacity(allocator, ARR_SIZE);

        helper.reset();
        for (0..ARR_SIZE) |_| {
            const val = helper.nextInt(1_000_000);
            self.data.appendAssumeCapacity(val);
        }

        return self;
    }

    pub fn deinit(self: *SortBenchmark) void {
        self.data.deinit(self.allocator);
    }

    pub fn checkNElements(self: *SortBenchmark, arr: []const i32, n_check: usize) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator); // Освобождаем с аллокатором

        const writer = buffer.writer(self.allocator);
        
        try writer.writeAll("[");

        const step = if (arr.len / n_check == 0) 1 else arr.len / n_check;
        var index: usize = 0;

        while (index < arr.len) {
            const slice = arr[index..@min(index + 1, arr.len)];
            if (slice.len > 0) {
                try writer.print("{}:{},", .{ index, slice[0] });
            }
            index += step;
        }

        try writer.writeAll("]\n");

        const result = try self.allocator.dupe(u8, buffer.items);
        return result;
    }
};