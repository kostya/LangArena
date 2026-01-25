// src/buffer_hash_crc32.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const BufferHashBenchmark = @import("buffer_hash_base.zig").BufferHashBenchmark;

pub const BufferHashCRC32 = struct {
    base: BufferHashBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BufferHashCRC32 {
        const self = try allocator.create(BufferHashCRC32);
        errdefer allocator.destroy(self);

        self.* = BufferHashCRC32{
            .base = try BufferHashBenchmark.init(allocator, helper, "BufferHashCRC32"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *BufferHashCRC32) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BufferHashCRC32) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    fn crc32(data: []const u8) u32 {
        var crc: u32 = 0xFFFFFFFF;

        for (data) |byte| {
            crc ^= @as(u32, byte);

            var j: u32 = 0;
            while (j < 8) : (j += 1) {
                if (crc & 1 == 1) {
                    crc = (crc >> 1) ^ 0xEDB88320;
                } else {
                    crc = crc >> 1;
                }
            }
        }

        return crc ^ 0xFFFFFFFF;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));

        self.base.result_val = 0;
        const n_int = @as(usize, @intCast(@max(self.base.n, 0)));

        for (0..n_int) |_| {
            const crc_result = crc32(self.base.data.items);
            self.base.result_val +%= crc_result;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.base.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
