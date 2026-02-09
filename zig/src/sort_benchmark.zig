const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const SortBenchmark = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(i32),
    size_val: i64,
    result_val: u64,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper, bench_name: []const u8) !SortBenchmark {
        const size_val = helper.configVal(bench_name, "size") orelse 100000;
        var self = SortBenchmark{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = size_val,
            .result_val = 0,
        };
        try self.data.ensureTotalCapacity(allocator, @as(usize, @intCast(size_val)));
        helper.reset();
        for (0..@as(usize, @intCast(size_val))) |_| {
            const val = helper.nextInt(1_000_000);
            self.data.appendAssumeCapacity(val);
        }
        return self;
    }

    pub fn deinit(self: *SortBenchmark) void {
        self.data.deinit(self.allocator);
    }
};
