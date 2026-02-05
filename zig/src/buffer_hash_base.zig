const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const BufferHashBenchmark = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(u8),
    size_val: i64,
    result_val: u64,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper, bench_name: []const u8) !BufferHashBenchmark {
        const size_val = helper.configVal(bench_name, "size") orelse 1000000;
        var self = BufferHashBenchmark{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = size_val,
            .result_val = 0,
        };
        try self.data.ensureTotalCapacity(allocator, @as(usize, @intCast(size_val)));
        helper.reset();
        for (0..@as(usize, @intCast(size_val))) |_| {
            const val = @as(u8, @intCast(helper.nextInt(256)));
            self.data.appendAssumeCapacity(val);
        }
        return self;
    }

    pub fn deinit(self: *BufferHashBenchmark) void {
        self.data.deinit(self.allocator);
    }

    pub fn hashFunc(self: *BufferHashBenchmark) u32 {
        _ = self;
        @compileError("hashFunc must be implemented by concrete hash class");
    }
};