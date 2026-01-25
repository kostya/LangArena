// src/buffer_hash_sha256.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const BufferHashBenchmark = @import("buffer_hash_base.zig").BufferHashBenchmark;

pub const BufferHashSHA256 = struct {
    base: BufferHashBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BufferHashSHA256 {
        const self = try allocator.create(BufferHashSHA256);
        errdefer allocator.destroy(self);

        self.* = BufferHashSHA256{
            .base = try BufferHashBenchmark.init(allocator, helper, "BufferHashSHA256"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *BufferHashSHA256) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BufferHashSHA256) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    fn simpleSHA256(data: []const u8) [32]u8 {
        var result: [32]u8 = undefined;

        // Упрощенный алгоритм хеширования (как в C++)
        var hashes = [8]u32{
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        };

        for (data, 0..) |byte_val, i| {
            const byte = @as(u32, @intCast(byte_val));
            const hash_idx = @as(usize, @intCast(i % 8)); // ИЗМЕНИТЬ!

            var hash = hashes[hash_idx];
            hash = ((hash << 5) +% hash) +% byte;
            hash = (hash +% (hash << 10)) ^ (hash >> 6);

            hashes[hash_idx] = hash;
        }

        // Точно как в C++: result[i * 4] = static_cast<uint8_t>(hashes[i] >> 24);
        for (0..8) |i| {
            result[i * 4] = @as(u8, @truncate(hashes[i] >> 24));
            result[i * 4 + 1] = @as(u8, @truncate(hashes[i] >> 16));
            result[i * 4 + 2] = @as(u8, @truncate(hashes[i] >> 8));
            result[i * 4 + 3] = @as(u8, @truncate(hashes[i]));
        }

        return result;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));

        self.base.result_val = 0;
        const n_int = @as(usize, @intCast(@max(self.base.n, 0)));

        for (0..n_int) |_| {
            const hash_result = simpleSHA256(self.base.data.items);
            // Читаем как LITTLE-ENDIAN (как в C++ на x86)
            const first_word = std.mem.readInt(u32, hash_result[0..4], .little);
            self.base.result_val +%= first_word;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.base.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BufferHashSHA256 = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
