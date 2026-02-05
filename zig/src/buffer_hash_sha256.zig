const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BufferHashSHA256 = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BufferHashSHA256 {
        const self = try allocator.create(BufferHashSHA256);
        errdefer allocator.destroy(self);

        self.* = BufferHashSHA256{
            .allocator = allocator,
            .helper = helper,
            .data = .{},
            .size_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *BufferHashSHA256) void {
        self.data.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BufferHashSHA256) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "BufferHashSHA256");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));

        if (self.size_val == 0) {
            self.size_val = self.helper.config_i64("BufferHashSHA256", "size");
            const size = @as(usize, @intCast(self.size_val));

            self.data.clearAndFree(self.allocator);
            self.data.ensureTotalCapacity(self.allocator, size) catch return;

            for (0..size) |_| {
                self.data.appendAssumeCapacity(@as(u8, @intCast(self.helper.nextInt(256))));
            }
        }
    }

    fn simpleSHA256(data: []const u8) [32]u8 {
        var result: [32]u8 = undefined;

        // Упрощенный алгоритм хеширования
        var hashes = [8]u32{
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        };

        for (data, 0..) |byte_val, i| {
            const byte = @as(u32, @intCast(byte_val));
            const hash_idx = @as(usize, @intCast(i % 8));

            var hash = hashes[hash_idx];
            hash = ((hash << 5) +% hash) +% byte;
            hash = (hash +% (hash << 10)) ^ (hash >> 6);

            hashes[hash_idx] = hash;
        }

        // Форматируем результат
        for (0..8) |i| {
            result[i * 4] = @as(u8, @truncate(hashes[i] >> 24));
            result[i * 4 + 1] = @as(u8, @truncate(hashes[i] >> 16));
            result[i * 4 + 2] = @as(u8, @truncate(hashes[i] >> 8));
            result[i * 4 + 3] = @as(u8, @truncate(hashes[i]));
        }

        return result;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const hash_result = simpleSHA256(self.data.items);
        const first_word = std.mem.readInt(u32, hash_result[0..4], .little);
        self.result_val +%= first_word;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};