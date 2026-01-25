// src/buffer_hash_base.zig
const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const BufferHashBenchmark = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(u8),
    n: i32,
    result_val: u64,

    const DATA_SIZE: usize = 1_000_000;

    pub fn init(allocator: std.mem.Allocator, helper: *Helper, bench_name: []const u8) !BufferHashBenchmark {
        var self = BufferHashBenchmark{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .n = 0,
            .result_val = 0,
        };

        self.n = helper.getInputInt(bench_name);

        // Заполняем данные случайными байтами
        try self.data.ensureTotalCapacity(allocator, DATA_SIZE);
        helper.reset();

        for (0..DATA_SIZE) |_| {
            const val = @as(u8, @intCast(helper.nextInt(256)));
            self.data.appendAssumeCapacity(val);
        }

        return self;
    }

    pub fn deinit(self: *BufferHashBenchmark) void {
        self.data.deinit(self.allocator);
    }

    // "Абстрактный" метод - должен быть переопределен
    pub fn hashFunc(self: *BufferHashBenchmark) u32 {
        _ = self;
        @compileError("hashFunc must be implemented by concrete hash class");
    }
};
