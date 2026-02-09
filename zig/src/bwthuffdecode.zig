const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const BWTHuffEncode = @import("bwthuffencode.zig").BWTHuffEncode;

pub const BWTHuffDecode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    compressed_data: ?BWTHuffEncode.CompressedData,
    decompressed: []u8,
    result_val: u32,

    fn decompress(compressed: *const BWTHuffEncode.CompressedData, allocator: std.mem.Allocator) ![]u8 {

        var tree_arena = std.heap.ArenaAllocator.init(allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        const huffman_tree = try BWTHuffEncode.buildHuffmanTree(&compressed.frequencies, tree_allocator);

        const decoded = try huffmanDecode(compressed.encoded_bits, huffman_tree, compressed.original_bit_count, allocator);
        defer allocator.free(decoded);

        const bwt_result = BWTHuffEncode.BWTResult{
            .transformed = decoded,
            .original_idx = compressed.bwt_result.original_idx,
        };
        const result = try bwtInverse(bwt_result, allocator);

        return result;
    }

    fn huffmanDecode(encoded: []const u8, root: *BWTHuffEncode.HuffmanNode, bit_count: u32, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(allocator);

        var current_node = root;
        var bits_processed: u32 = 0;
        var byte_idx: usize = 0;

        while (bits_processed < bit_count and byte_idx < encoded.len) {
            const byte_val = encoded[byte_idx];
            byte_idx += 1;

            var bit_pos: u32 = 8;
            while (bit_pos > 0 and bits_processed < bit_count) {
                bit_pos -= 1;
                bits_processed += 1;

                const bit = (byte_val >> @as(u3, @intCast(bit_pos))) & 1;

                current_node = if (bit == 1)
                    current_node.right.?
                else
                    current_node.left.?;

                if (current_node.is_leaf) {

                    if (current_node.byte_val != 0) {
                        try result.append(allocator, current_node.byte_val);
                    }
                    current_node = root;
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }

    fn bwtInverse(bwt_result: BWTHuffEncode.BWTResult, allocator: std.mem.Allocator) ![]u8 {
        const bwt = bwt_result.transformed;
        const n = bwt.len;
        if (n == 0) {
            return &.{};
        }

        var counts: [256]usize = [_]usize{0} ** 256;
        for (bwt) |byte| {
            counts[byte] += 1;
        }

        var positions: [256]usize = [_]usize{0} ** 256;
        var total: usize = 0;
        for (0..256) |i| {
            positions[i] = total;
            total += counts[i];
        }

        var next = try allocator.alloc(usize, n);
        defer allocator.free(next);
        @memset(next, 0);

        var temp_counts: [256]usize = [_]usize{0} ** 256;

        for (0..n) |i| {
            const byte = bwt[i];
            const pos = positions[byte] + temp_counts[byte];
            next[pos] = i;
            temp_counts[byte] += 1;
        }

        var result = try allocator.alloc(u8, n);
        var idx = bwt_result.original_idx;

        for (0..n) |i| {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BWTHuffDecode {
        const size = helper.config_i64("BWTHuffDecode", "size");
        const self = try allocator.create(BWTHuffDecode);
        self.* = BWTHuffDecode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .compressed_data = null,
            .decompressed = &.{},
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BWTHuffDecode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.compressed_data) |*compressed| {
            compressed.deinit(self.allocator);
        }
        if (self.decompressed.len > 0) {
            self.allocator.free(self.decompressed);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BWTHuffDecode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "BWTHuffDecode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.compressed_data) |*compressed| {
            compressed.deinit(self.allocator);
        }
        if (self.decompressed.len > 0) {
            self.allocator.free(self.decompressed);
        }

        self.test_data = BWTHuffEncode.generateTestData(self.size_val, self.allocator) catch &.{};

        self.compressed_data = BWTHuffEncode.compress(self.test_data, self.allocator) catch null;
        self.decompressed = &.{};
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));

        if (self.compressed_data) |*compressed| {

            const decompressed = decompress(compressed, self.allocator) catch return;

            if (self.decompressed.len > 0) {
                self.allocator.free(self.decompressed);
            }

            self.decompressed = decompressed;

            self.result_val +%= @as(u32, @intCast(self.decompressed.len));
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));

        var res = self.result_val;

        if (self.test_data.len > 0 and self.decompressed.len > 0) {
            if (std.mem.eql(u8, self.test_data, self.decompressed)) {
                res +%= 1000000;
            }
        }

        return res;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};