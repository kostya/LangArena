const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BufferHashCRC32 = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    data: std.ArrayListUnmanaged(u8),
    size_val: i64,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BufferHashCRC32 {
        const self = try allocator.create(BufferHashCRC32);
        errdefer allocator.destroy(self);

        self.* = BufferHashCRC32{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *BufferHashCRC32) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BufferHashCRC32) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "BufferHashCRC32");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));

        if (self.size_val == 0) {
            self.size_val = self.helper.config_i64("BufferHashCRC32", "size");
            const size = @as(usize, @intCast(self.size_val));

            self.data.clearAndFree(self.allocator);
            self.data.ensureTotalCapacity(self.allocator, size) catch return;

            for (0..size) |_| {
                self.data.appendAssumeCapacity(@as(u8, @intCast(self.helper.nextInt(256))));
            }
        }
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

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const crc_result = crc32(self.data.items);
        self.result_val +%= crc_result;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BufferHashCRC32 = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
