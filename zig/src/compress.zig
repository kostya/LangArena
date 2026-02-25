const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

fn generateTestData(size: i64, allocator: std.mem.Allocator) ![]u8 {
    const pattern = "ABRACADABRA";
    var data = try allocator.alloc(u8, @as(usize, @intCast(size)));
    for (0..@as(usize, @intCast(size))) |i| {
        data[i] = pattern[i % pattern.len];
    }
    return data;
}

pub const BWTEncode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    bwt_result: BWTResult,
    result_val: u32,

    pub const BWTResult = struct {
        transformed: []u8,
        original_idx: usize,

        fn deinit(self: *BWTResult, allocator: std.mem.Allocator) void {
            if (self.transformed.len > 0) {
                allocator.free(self.transformed);
            }
        }
    };

    fn bwtTransform(data: []const u8, allocator: std.mem.Allocator) !BWTResult {
        const n = data.len;
        if (n == 0) return BWTResult{ .transformed = &.{}, .original_idx = 0 };

        var sa = try allocator.alloc(usize, n);
        errdefer allocator.free(sa);
        for (0..n) |i| sa[i] = i;

        var counts = [_]usize{0} ** 256;
        for (data) |byte| {
            counts[byte] += 1;
        }

        var positions = [_]usize{0} ** 256;
        var total: usize = 0;
        for (0..256) |i| {
            positions[i] = total;
            total += counts[i];
            counts[i] = 0;
        }

        var temp_sa = try allocator.alloc(usize, n);
        defer allocator.free(temp_sa);

        for (0..n) |i| {
            const idx = sa[i];
            const byte_val = data[idx];
            const pos = positions[byte_val] + counts[byte_val];
            temp_sa[pos] = idx;
            counts[byte_val] += 1;
        }

        @memcpy(sa, temp_sa);

        if (n > 1) {
            var rank = try allocator.alloc(i32, n);
            defer allocator.free(rank);

            var current_rank: i32 = 0;
            var prev_char = data[sa[0]];
            rank[sa[0]] = current_rank;

            for (1..n) |i| {
                const idx = sa[i];
                if (data[idx] != prev_char) {
                    current_rank += 1;
                    prev_char = data[idx];
                }
                rank[idx] = current_rank;
            }

            var k: usize = 1;
            while (k < n) {
                var pairs = try allocator.alloc([2]i32, n);
                defer allocator.free(pairs);

                for (0..n) |i| {
                    pairs[i] = .{ rank[i], rank[(i + k) % n] };
                }

                std.sort.block(usize, sa, pairs, struct {
                    fn lessThan(pairs2: [][2]i32, a: usize, b: usize) bool {
                        const pa = pairs2[a];
                        const pb = pairs2[b];
                        if (pa[0] != pb[0]) return pa[0] < pb[0];
                        return pa[1] < pb[1];
                    }
                }.lessThan);

                var new_rank = try allocator.alloc(i32, n);
                defer allocator.free(new_rank);

                new_rank[sa[0]] = 0;
                for (1..n) |i| {
                    const prev = sa[i - 1];
                    const curr = sa[i];
                    if (!std.meta.eql(pairs[prev], pairs[curr])) {
                        new_rank[curr] = new_rank[prev] + 1;
                    } else {
                        new_rank[curr] = new_rank[prev];
                    }
                }

                @memcpy(rank, new_rank);
                k *= 2;
            }
        }

        var transformed = try allocator.alloc(u8, n);
        var original_idx: usize = 0;

        for (0..n) |i| {
            const suffix = sa[i];
            if (suffix == 0) {
                transformed[i] = data[n - 1];
                original_idx = i;
            } else {
                transformed[i] = data[suffix - 1];
            }
        }

        allocator.free(sa);
        return BWTResult{ .transformed = transformed, .original_idx = original_idx };
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BWTEncode {
        const size = helper.config_i64("Compress::BWTEncode", "size");
        const self = try allocator.create(BWTEncode);
        self.* = BWTEncode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .bwt_result = undefined,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BWTEncode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }

        if (self.bwt_result.transformed.len > 0) {
            self.bwt_result.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BWTEncode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::BWTEncode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BWTEncode = @ptrCast(@alignCast(ptr));
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        self.test_data = generateTestData(self.size_val, self.allocator) catch &.{};
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *BWTEncode = @ptrCast(@alignCast(ptr));

        if (self.bwt_result.transformed.len > 0) {
            self.bwt_result.deinit(self.allocator);
        }

        self.bwt_result = bwtTransform(self.test_data, self.allocator) catch {
            self.bwt_result = BWTResult{ .transformed = &.{}, .original_idx = 0 };
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.bwt_result.transformed.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *BWTEncode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BWTEncode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const BWTDecode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    inverted: []u8,
    bwt_result: BWTEncode.BWTResult,
    result_val: u32,

    fn bwtInverse(bwt_result: BWTEncode.BWTResult, allocator: std.mem.Allocator) ![]u8 {
        const bwt = bwt_result.transformed;
        const n = bwt.len;
        if (n == 0) return &.{};

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
        errdefer allocator.free(next);

        var temp_counts: [256]usize = [_]usize{0} ** 256;
        for (0..n) |i| {
            const byte = bwt[i];
            const pos = positions[byte] + temp_counts[byte];
            next[pos] = i;
            temp_counts[byte] += 1;
        }

        var result = try allocator.alloc(u8, n);
        errdefer allocator.free(result);

        var idx = bwt_result.original_idx;
        for (0..n) |i| {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        allocator.free(next);
        return result;
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BWTDecode {
        const size = helper.config_i64("Compress::BWTDecode", "size");
        const self = try allocator.create(BWTDecode);
        self.* = BWTDecode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .inverted = &.{},
            .bwt_result = .{
                .transformed = &.{},
                .original_idx = 0,
            },
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BWTDecode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.inverted.len > 0) {
            self.allocator.free(self.inverted);
        }
        if (self.bwt_result.transformed.len > 0) {
            self.bwt_result.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BWTDecode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::BWTDecode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BWTDecode = @ptrCast(@alignCast(ptr));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }
        if (self.bwt_result.transformed.len > 0) {
            self.bwt_result.deinit(self.allocator);
            self.bwt_result = .{
                .transformed = &.{},
                .original_idx = 0,
            };
        }

        var encoder = BWTEncode.init(self.allocator, self.helper) catch return;
        defer encoder.deinit();

        encoder.size_val = self.size_val;
        BWTEncode.prepareImpl(@ptrCast(encoder));
        BWTEncode.runImpl(@ptrCast(encoder), 0);

        self.test_data = self.allocator.dupe(u8, encoder.test_data) catch {
            self.test_data = &.{};
            return;
        };

        self.bwt_result = .{
            .transformed = self.allocator.dupe(u8, encoder.bwt_result.transformed) catch {
                self.allocator.free(self.test_data);
                self.test_data = &.{};
                self.bwt_result = .{ .transformed = &.{}, .original_idx = 0 };
                return;
            },
            .original_idx = encoder.bwt_result.original_idx,
        };

        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *BWTDecode = @ptrCast(@alignCast(ptr));

        if (self.inverted.len > 0) {
            self.allocator.free(self.inverted);
            self.inverted = &.{};
        }

        self.inverted = bwtInverse(self.bwt_result, self.allocator) catch {
            self.inverted = &.{};
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.inverted.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *BWTDecode = @ptrCast(@alignCast(ptr));

        var res = self.result_val;
        if (self.test_data.len > 0 and self.inverted.len > 0) {
            if (std.mem.eql(u8, self.test_data, self.inverted)) {
                res +%= 100000;
            }
        }
        return res;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BWTDecode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

const HuffmanNode = struct {
    frequency: u32,
    byte_val: u8,
    is_leaf: bool,
    left: ?*HuffmanNode,
    right: ?*HuffmanNode,

    fn init(freq: u32, byte: u8, leaf: bool) HuffmanNode {
        return HuffmanNode{
            .frequency = freq,
            .byte_val = byte,
            .is_leaf = leaf,
            .left = null,
            .right = null,
        };
    }
};

const HuffmanCodes = struct {
    code_lengths: [256]u8,
    codes: [256]u32,

    fn init() HuffmanCodes {
        return HuffmanCodes{
            .code_lengths = [_]u8{0} ** 256,
            .codes = [_]u32{0} ** 256,
        };
    }
};

const EncodedResult = struct {
    data: []u8,
    bit_count: u32,
    frequencies: [256]u32,

    fn init(data: []u8, bit_count: u32, frequencies: [256]u32) EncodedResult {
        return EncodedResult{
            .data = data,
            .bit_count = bit_count,
            .frequencies = frequencies,
        };
    }

    fn deinit(self: *EncodedResult, allocator: std.mem.Allocator) void {
        if (self.data.len > 0) {
            allocator.free(self.data);
            self.data = &.{};
        }
    }
};

pub const HuffEncode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    encoded: EncodedResult,
    result_val: u32,

    fn buildHuffmanTree(frequencies: []const u32, allocator: std.mem.Allocator) !?*HuffmanNode {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var nodes = std.ArrayList(*HuffmanNode).empty;
        defer nodes.deinit(arena_allocator);

        for (0..256) |i| {
            if (frequencies[i] > 0) {
                const node = try arena_allocator.create(HuffmanNode);
                node.* = HuffmanNode.init(frequencies[i], @as(u8, @intCast(i)), true);

                try nodes.append(arena_allocator, node);
            }
        }

        std.sort.block(*HuffmanNode, nodes.items, {}, struct {
            fn lessThan(_: void, a: *HuffmanNode, b: *HuffmanNode) bool {
                return a.frequency < b.frequency;
            }
        }.lessThan);

        if (nodes.items.len == 1) {
            const leaf = nodes.orderedRemove(0);
            const dummy = try arena_allocator.create(HuffmanNode);
            dummy.* = HuffmanNode.init(0, 0, true);

            const root = try arena_allocator.create(HuffmanNode);
            root.* = HuffmanNode.init(leaf.frequency, 0, false);
            root.left = leaf;
            root.right = dummy;
            return root;
        }

        while (nodes.items.len > 1) {
            const left = nodes.orderedRemove(0);
            const right = nodes.orderedRemove(0);

            const parent = try arena_allocator.create(HuffmanNode);
            parent.* = HuffmanNode.init(left.frequency + right.frequency, 0, false);
            parent.left = left;
            parent.right = right;

            var insert_idx: usize = 0;
            while (insert_idx < nodes.items.len and nodes.items[insert_idx].frequency < parent.frequency) {
                insert_idx += 1;
            }

            try nodes.insert(arena_allocator, insert_idx, parent);
        }

        return if (nodes.items.len > 0) nodes.items[0] else null;
    }
    fn buildHuffmanCodes(node: *HuffmanNode, code: u32, length: u8, huffman_codes: *HuffmanCodes) void {
        if (node.is_leaf) {
            if (length > 0 or node.byte_val != 0) {
                const idx = node.byte_val;
                huffman_codes.code_lengths[idx] = length;
                huffman_codes.codes[idx] = code;
            }
        } else {
            if (node.left) |left| {
                buildHuffmanCodes(left, code << 1, length + 1, huffman_codes);
            }
            if (node.right) |right| {
                buildHuffmanCodes(right, (code << 1) | 1, length + 1, huffman_codes);
            }
        }
    }

    fn huffmanEncode(data: []const u8, codes: *const HuffmanCodes, frequencies: [256]u32, allocator: std.mem.Allocator) !EncodedResult {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(allocator);
        try result.ensureTotalCapacity(allocator, data.len * 2);

        var current_byte: u8 = 0;
        var bit_pos: u8 = 0;
        var total_bits: u32 = 0;

        for (data) |byte| {
            const idx = byte;
            const code = codes.codes[idx];
            const length = codes.code_lengths[idx];

            var i = length;
            while (i > 0) {
                i -= 1;
                if ((code & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0) {
                    current_byte |= @as(u8, 1) << @as(u3, @intCast(7 - bit_pos));
                }
                bit_pos += 1;
                total_bits += 1;

                if (bit_pos == 8) {
                    try result.append(allocator, current_byte);
                    current_byte = 0;
                    bit_pos = 0;
                }
            }
        }

        if (bit_pos > 0) {
            try result.append(allocator, current_byte);
        }

        return EncodedResult.init(try result.toOwnedSlice(allocator), total_bits, frequencies);
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*HuffEncode {
        const size = helper.config_i64("Compress::HuffEncode", "size");
        const self = try allocator.create(HuffEncode);
        self.* = HuffEncode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .encoded = undefined,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *HuffEncode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (@intFromPtr(&self.encoded) != 0 and self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *HuffEncode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::HuffEncode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *HuffEncode = @ptrCast(@alignCast(ptr));
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        self.test_data = generateTestData(self.size_val, self.allocator) catch &.{};
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *HuffEncode = @ptrCast(@alignCast(ptr));

        if (self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }

        var frequencies: [256]u32 = [_]u32{0} ** 256;
        for (self.test_data) |byte| {
            frequencies[byte] += 1;
        }

        var tree_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        const tree = HuffEncode.buildHuffmanTree(&frequencies, tree_allocator) catch {
            self.encoded = EncodedResult.init(&.{}, 0, frequencies);
            return;
        };

        var huffman_codes = HuffmanCodes.init();
        if (tree) |t| {
            HuffEncode.buildHuffmanCodes(t, 0, 0, &huffman_codes);
        }

        self.encoded = HuffEncode.huffmanEncode(self.test_data, &huffman_codes, frequencies, self.allocator) catch {
            self.encoded = EncodedResult.init(&.{}, 0, frequencies);
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.encoded.data.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *HuffEncode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *HuffEncode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const HuffDecode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    decoded: []u8,
    encoded: EncodedResult,
    result_val: u32,

    fn huffmanDecode(encoded: []const u8, root: *HuffmanNode, bit_count: u32, allocator: std.mem.Allocator) ![]u8 {
        var result = try allocator.alloc(u8, bit_count);
        var result_size: usize = 0;

        var current_node = root;
        var bits_processed: u32 = 0;
        var byte_idx: usize = 0;

        while (bits_processed < bit_count and byte_idx < encoded.len) {
            const byte_val = encoded[byte_idx];
            byte_idx += 1;

            var bit_pos: u3 = 7;
            while (true) {
                if (bits_processed >= bit_count) break;

                const bit = (byte_val >> bit_pos) & 1;
                bits_processed += 1;

                current_node = if (bit == 1)
                    current_node.right.?
                else
                    current_node.left.?;

                if (current_node.is_leaf) {
                    if (current_node.byte_val != 0) {
                        result[result_size] = current_node.byte_val;
                        result_size += 1;
                    }
                    current_node = root;
                }

                if (bit_pos == 0) break;
                bit_pos -= 1;
            }
        }

        if (result_size < bit_count) {
            return allocator.realloc(result, result_size);
        }
        return result;
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*HuffDecode {
        const size = helper.config_i64("Compress::HuffDecode", "size");
        const self = try allocator.create(HuffDecode);
        self.* = HuffDecode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .decoded = &.{},
            .encoded = undefined,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *HuffDecode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
        }
        if (@intFromPtr(&self.encoded) != 0 and self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *HuffDecode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::HuffDecode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *HuffDecode = @ptrCast(@alignCast(ptr));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }
        if (self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
            self.decoded = &.{};
        }

        var encoder = HuffEncode.init(self.allocator, self.helper) catch return;
        defer encoder.deinit();

        encoder.size_val = self.size_val;
        HuffEncode.prepareImpl(@ptrCast(encoder));
        HuffEncode.runImpl(@ptrCast(encoder), 0);

        self.test_data = self.allocator.dupe(u8, encoder.test_data) catch {
            self.test_data = &.{};
            return;
        };

        self.encoded = .{
            .data = self.allocator.dupe(u8, encoder.encoded.data) catch {
                self.allocator.free(self.test_data);
                self.test_data = &.{};
                self.encoded = undefined;
                return;
            },
            .bit_count = encoder.encoded.bit_count,
            .frequencies = encoder.encoded.frequencies,
        };

        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *HuffDecode = @ptrCast(@alignCast(ptr));

        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
            self.decoded = &.{};
        }

        var tree_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        const huffman_tree = HuffEncode.buildHuffmanTree(&self.encoded.frequencies, tree_allocator) catch {
            self.decoded = &.{};
            return;
        };

        self.decoded = huffmanDecode(
            self.encoded.data,
            huffman_tree.?,
            self.encoded.bit_count,
            self.allocator,
        ) catch {
            self.decoded = &.{};
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.decoded.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *HuffDecode = @ptrCast(@alignCast(ptr));

        var res = self.result_val;
        if (self.test_data.len > 0 and self.decoded.len > 0) {
            if (std.mem.eql(u8, self.test_data, self.decoded)) {
                res +%= 100000;
            }
        }
        return res;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *HuffDecode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

const ArithFreqTable = struct {
    total: u32,
    low: [256]u32,
    high: [256]u32,

    fn init(frequencies: []const u32) ArithFreqTable {
        var ft = ArithFreqTable{
            .total = 0,
            .low = [_]u32{0} ** 256,
            .high = [_]u32{0} ** 256,
        };

        for (frequencies) |f| {
            ft.total += f;
        }

        var cum: u32 = 0;
        for (0..256) |i| {
            ft.low[i] = cum;
            cum += frequencies[i];
            ft.high[i] = cum;
        }

        return ft;
    }
};

const BitOutputStream = struct {
    buffer: u32,
    bit_pos: u8,
    bytes: std.ArrayList(u8),
    bits_written: u32,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) BitOutputStream {
        return BitOutputStream{
            .buffer = 0,
            .bit_pos = 0,
            .bytes = .empty,
            .bits_written = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *BitOutputStream) void {
        self.bytes.deinit(self.allocator);
    }

    fn writeBit(self: *BitOutputStream, bit: u1) !void {
        self.buffer = (self.buffer << 1) | @as(u32, bit);
        self.bit_pos += 1;
        self.bits_written += 1;

        if (self.bit_pos == 8) {
            try self.bytes.append(self.allocator, @as(u8, @truncate(self.buffer & 0xFF)));
            self.buffer = 0;
            self.bit_pos = 0;
        }
    }

    fn flush(self: *BitOutputStream) ![]u8 {
        if (self.bit_pos > 0) {
            self.buffer <<= @as(u5, @intCast(8 - self.bit_pos));
            try self.bytes.append(self.allocator, @as(u8, @truncate(self.buffer & 0xFF)));
        }
        return try self.bytes.toOwnedSlice(self.allocator);
    }
};

const ArithEncodedResult = struct {
    data: []u8,
    bit_count: u32,
    frequencies: [256]u32,

    fn deinit(self: *ArithEncodedResult, allocator: std.mem.Allocator) void {
        if (self.data.len > 0) {
            allocator.free(self.data);
        }
    }
};

pub const ArithEncode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    encoded: ArithEncodedResult,
    result_val: u32,

    fn arithEncode(data: []const u8, allocator: std.mem.Allocator) !ArithEncodedResult {
        var frequencies: [256]u32 = [_]u32{0} ** 256;
        for (data) |byte| {
            frequencies[byte] += 1;
        }

        const freq_table = ArithFreqTable.init(&frequencies);

        var low: u64 = 0;
        var high: u64 = 0xFFFFFFFF;
        var pending: u32 = 0;
        var output = BitOutputStream.init(allocator);
        defer output.deinit();

        for (data) |byte| {
            const idx = byte;
            const range = high - low + 1;

            high = low + (range * @as(u64, freq_table.high[idx]) / @as(u64, freq_table.total)) - 1;
            low = low + (range * @as(u64, freq_table.low[idx]) / @as(u64, freq_table.total));

            while (true) {
                if (high < 0x80000000) {
                    try output.writeBit(0);
                    var i: u32 = 0;
                    while (i < pending) : (i += 1) {
                        try output.writeBit(1);
                    }
                    pending = 0;
                } else if (low >= 0x80000000) {
                    try output.writeBit(1);
                    var i: u32 = 0;
                    while (i < pending) : (i += 1) {
                        try output.writeBit(0);
                    }
                    pending = 0;
                    low -= 0x80000000;
                    high -= 0x80000000;
                } else if (low >= 0x40000000 and high < 0xC0000000) {
                    pending += 1;
                    low -= 0x40000000;
                    high -= 0x40000000;
                } else {
                    break;
                }

                low <<= 1;
                high = (high << 1) | 1;
                high &= 0xFFFFFFFF;
            }
        }

        pending += 1;
        if (low < 0x40000000) {
            try output.writeBit(0);
            var i: u32 = 0;
            while (i < pending) : (i += 1) {
                try output.writeBit(1);
            }
        } else {
            try output.writeBit(1);
            var i: u32 = 0;
            while (i < pending) : (i += 1) {
                try output.writeBit(0);
            }
        }

        const encoded_data = try output.flush();
        return ArithEncodedResult{
            .data = encoded_data,
            .bit_count = output.bits_written,
            .frequencies = frequencies,
        };
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*ArithEncode {
        const size = helper.config_i64("Compress::ArithEncode", "size");
        const self = try allocator.create(ArithEncode);
        self.* = ArithEncode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .encoded = undefined,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *ArithEncode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (@intFromPtr(&self.encoded) != 0 and self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *ArithEncode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::ArithEncode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *ArithEncode = @ptrCast(@alignCast(ptr));
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        self.test_data = generateTestData(self.size_val, self.allocator) catch &.{};
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *ArithEncode = @ptrCast(@alignCast(ptr));
        if (@intFromPtr(&self.encoded) != 0 and self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        self.encoded = arithEncode(self.test_data, self.allocator) catch return;
        self.result_val +%= @as(u32, @intCast(self.encoded.data.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *ArithEncode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *ArithEncode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

const BitInputStream = struct {
    bytes: []const u8,
    byte_pos: usize,
    bit_pos: u8,
    current_byte: u8,

    fn init(bytes: []const u8) BitInputStream {
        return BitInputStream{
            .bytes = bytes,
            .byte_pos = 0,
            .bit_pos = 0,
            .current_byte = if (bytes.len > 0) bytes[0] else 0,
        };
    }

    fn readBit(self: *BitInputStream) u1 {
        if (self.bit_pos == 8) {
            self.byte_pos += 1;
            self.bit_pos = 0;
            self.current_byte = if (self.byte_pos < self.bytes.len) self.bytes[self.byte_pos] else 0;
        }

        const bit = @as(u1, @truncate((self.current_byte >> @as(u3, @intCast(7 - self.bit_pos))) & 1));
        self.bit_pos += 1;
        return bit;
    }
};

pub const ArithDecode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    decoded: []u8,
    encoded: ArithEncodedResult,
    result_val: u32,

    fn arithDecode(encoded: ArithEncodedResult, allocator: std.mem.Allocator) ![]u8 {
        const frequencies = encoded.frequencies;
        var total: u32 = 0;
        for (frequencies) |f| {
            total += f;
        }
        const data_size = total;

        var low_table: [256]u32 = undefined;
        var high_table: [256]u32 = undefined;
        var cum: u32 = 0;
        for (0..256) |i| {
            low_table[i] = cum;
            cum += frequencies[i];
            high_table[i] = cum;
        }

        var result = try allocator.alloc(u8, data_size);
        var input = BitInputStream.init(encoded.data);

        var value: u64 = 0;
        for (0..32) |_| {
            value = (value << 1) | @as(u64, input.readBit());
        }

        var low: u64 = 0;
        var high: u64 = 0xFFFFFFFF;

        for (0..data_size) |j| {
            const range = high - low + 1;
            const scaled = ((value - low + 1) * @as(u64, total) - 1) / range;

            var symbol: u8 = 0;
            while (symbol < 255 and @as(u64, high_table[symbol]) <= scaled) {
                symbol += 1;
            }

            result[j] = symbol;

            high = low + (range * @as(u64, high_table[symbol]) / @as(u64, total)) - 1;
            low = low + (range * @as(u64, low_table[symbol]) / @as(u64, total));

            while (true) {
                if (high < 0x80000000) {} else if (low >= 0x80000000) {
                    value -= 0x80000000;
                    low -= 0x80000000;
                    high -= 0x80000000;
                } else if (low >= 0x40000000 and high < 0xC0000000) {
                    value -= 0x40000000;
                    low -= 0x40000000;
                    high -= 0x40000000;
                } else {
                    break;
                }

                low <<= 1;
                high = (high << 1) | 1;
                value = (value << 1) | @as(u64, input.readBit());
            }
        }

        return result;
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*ArithDecode {
        const size = helper.config_i64("Compress::ArithDecode", "size");
        const self = try allocator.create(ArithDecode);
        self.* = ArithDecode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .decoded = &.{},
            .encoded = undefined,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *ArithDecode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
        }
        if (@intFromPtr(&self.encoded) != 0 and self.encoded.data.len > 0) {
            self.encoded.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *ArithDecode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::ArithDecode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *ArithDecode = @ptrCast(@alignCast(ptr));

        var encoder = ArithEncode.init(self.allocator, self.helper) catch return;
        defer encoder.deinit();
        encoder.size_val = self.size_val;
        ArithEncode.prepareImpl(@ptrCast(encoder));
        ArithEncode.runImpl(@ptrCast(encoder), 0);

        self.test_data = self.allocator.dupe(u8, encoder.test_data) catch &.{};
        self.encoded = .{
            .data = self.allocator.dupe(u8, encoder.encoded.data) catch &.{},
            .bit_count = encoder.encoded.bit_count,
            .frequencies = encoder.encoded.frequencies,
        };
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *ArithDecode = @ptrCast(@alignCast(ptr));
        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
        }
        self.decoded = arithDecode(self.encoded, self.allocator) catch return;
        self.result_val +%= @as(u32, @intCast(self.decoded.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *ArithDecode = @ptrCast(@alignCast(ptr));

        var res = self.result_val;
        if (self.test_data.len > 0 and self.decoded.len > 0) {
            if (std.mem.eql(u8, self.test_data, self.decoded)) {
                res +%= 100000;
            }
        }
        return res;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *ArithDecode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

const LZWResult = struct {
    data: []u8,
    dict_size: u32,

    fn deinit(self: *LZWResult, allocator: std.mem.Allocator) void {
        if (self.data.len > 0) {
            allocator.free(self.data);
            self.data = &.{};
        }
    }
};

fn lzwEncode(input: []const u8, allocator: std.mem.Allocator) !LZWResult {
    if (input.len == 0) {
        return LZWResult{ .data = &.{}, .dict_size = 256 };
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var dict = std.StringHashMap(u32).init(arena_alloc);
    defer dict.deinit();

    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        const key = try arena_alloc.dupe(u8, &[_]u8{@as(u8, @intCast(i))});
        try dict.put(key, i);
    }

    var next_code: u32 = 256;

    var result = std.ArrayList(u8).empty;
    defer result.deinit(allocator);

    try result.ensureTotalCapacity(allocator, input.len * 2);

    var current_start: usize = 0;
    var current_len: usize = 1;

    i = 1;
    while (i < input.len) : (i += 1) {
        const next_char = input[i];

        var temp_buf: [4096]u8 = undefined;

        const new_str = if (current_len + 1 <= temp_buf.len) blk: {
            @memcpy(temp_buf[0..current_len], input[current_start .. current_start + current_len]);
            temp_buf[current_len] = next_char;
            break :blk temp_buf[0 .. current_len + 1];
        } else blk: {
            const allocated = try std.fmt.allocPrint(arena_alloc, "{s}{c}", .{ input[current_start .. current_start + current_len], next_char });
            break :blk allocated;
        };

        if (dict.contains(new_str)) {
            current_len += 1;
        } else {
            const code = dict.get(input[current_start .. current_start + current_len]) orelse return error.InvalidState;

            try result.append(allocator, @as(u8, @intCast((code >> 8) & 0xFF)));
            try result.append(allocator, @as(u8, @intCast(code & 0xFF)));

            const new_key = try arena_alloc.dupe(u8, new_str);
            try dict.put(new_key, next_code);

            next_code += 1;

            current_start = i;
            current_len = 1;
        }
    }

    const last_code = dict.get(input[current_start .. current_start + current_len]) orelse return error.InvalidState;
    try result.append(allocator, @as(u8, @intCast((last_code >> 8) & 0xFF)));
    try result.append(allocator, @as(u8, @intCast(last_code & 0xFF)));

    const result_slice = try result.toOwnedSlice(allocator);

    return LZWResult{
        .data = result_slice,
        .dict_size = next_code,
    };
}

fn lzwDecode(encoded: LZWResult, allocator: std.mem.Allocator) ![]u8 {
    if (encoded.data.len == 0) return &.{};

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var dict = std.ArrayList([]u8).empty;
    defer dict.deinit(arena_alloc);

    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        const entry = try arena_alloc.dupe(u8, &[_]u8{@as(u8, @intCast(i))});
        try dict.append(arena_alloc, entry);
    }

    var result = std.ArrayList(u8).empty;
    defer result.deinit(allocator);

    try result.ensureTotalCapacity(allocator, encoded.data.len * 4);

    const data = encoded.data;
    var pos: usize = 0;

    const first_code = (@as(u32, data[pos]) << 8) | @as(u32, data[pos + 1]);
    pos += 2;

    if (first_code >= dict.items.len) return error.InvalidCode;

    const first_str = dict.items[first_code];
    try result.appendSlice(allocator, first_str);

    var previous_code = first_code;
    var previous_str = first_str;
    var next_code: u32 = 256;

    while (pos < data.len) {
        const current_code = (@as(u32, data[pos]) << 8) | @as(u32, data[pos + 1]);
        pos += 2;

        const current_str = if (current_code < dict.items.len) blk: {
            break :blk dict.items[current_code];
        } else if (current_code == next_code) blk: {
            const entry = try arena_alloc.alloc(u8, previous_str.len + 1);
            @memcpy(entry[0..previous_str.len], previous_str);
            entry[previous_str.len] = previous_str[0];
            break :blk entry;
        } else {
            return error.InvalidCode;
        };

        try result.appendSlice(allocator, current_str);

        const new_entry = try arena_alloc.alloc(u8, previous_str.len + 1);
        @memcpy(new_entry[0..previous_str.len], previous_str);
        new_entry[previous_str.len] = current_str[0];
        try dict.append(arena_alloc, new_entry);

        next_code += 1;
        previous_code = current_code;
        previous_str = current_str;
    }

    const result_slice = try result.toOwnedSlice(allocator);
    return result_slice;
}
pub const LZWEncode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    encoded: LZWResult,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = run,
        .checksum = checksum,
        .prepare = prepare,
        .deinit = deinit,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*LZWEncode {
        const size = helper.config_i64("Compress::LZWEncode", "size");
        const self = try allocator.create(LZWEncode);
        self.* = LZWEncode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .encoded = LZWResult{ .data = &.{}, .dict_size = 256 },
            .result_val = 0,
        };
        return self;
    }

    pub fn asBenchmark(self: *LZWEncode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::LZWEncode");
    }

    fn prepare(ctx: *anyopaque) void {
        const self: *LZWEncode = @ptrCast(@alignCast(ctx));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }

        self.encoded.deinit(self.allocator);

        self.test_data = generateTestData(self.size_val, self.allocator) catch {
            self.test_data = &.{};
            return;
        };

        self.result_val = 0;
    }

    fn run(ctx: *anyopaque, _: i64) void {
        const self: *LZWEncode = @ptrCast(@alignCast(ctx));

        self.encoded.deinit(self.allocator);

        self.encoded = lzwEncode(self.test_data, self.allocator) catch {
            self.encoded = LZWResult{ .data = &.{}, .dict_size = 256 };
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.encoded.data.len));
    }

    fn checksum(ctx: *anyopaque) u32 {
        const self: *LZWEncode = @ptrCast(@alignCast(ctx));
        return self.result_val;
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *LZWEncode = @ptrCast(@alignCast(ctx));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }

        self.encoded.deinit(self.allocator);

        self.allocator.destroy(self);
    }
};

pub const LZWDecode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
    decoded: []u8,
    encoded: LZWResult,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = run,
        .checksum = checksum,
        .prepare = prepare,
        .deinit = deinit,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*LZWDecode {
        const size = helper.config_i64("Compress::LZWDecode", "size");
        const self = try allocator.create(LZWDecode);
        self.* = LZWDecode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .decoded = &.{},
            .encoded = LZWResult{ .data = &.{}, .dict_size = 256 },
            .result_val = 0,
        };
        return self;
    }

    pub fn asBenchmark(self: *LZWDecode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Compress::LZWDecode");
    }

    fn prepare(ctx: *anyopaque) void {
        const self: *LZWDecode = @ptrCast(@alignCast(ctx));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }

        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
            self.decoded = &.{};
        }

        self.encoded.deinit(self.allocator);

        self.test_data = generateTestData(self.size_val, self.allocator) catch {
            self.test_data = &.{};
            return;
        };

        const encode_result = lzwEncode(self.test_data, self.allocator) catch {
            self.encoded = LZWResult{ .data = &.{}, .dict_size = 256 };
            return;
        };

        self.encoded = encode_result;

        self.result_val = 0;
    }

    fn run(ctx: *anyopaque, _: i64) void {
        const self: *LZWDecode = @ptrCast(@alignCast(ctx));

        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
            self.decoded = &.{};
        }

        self.decoded = lzwDecode(self.encoded, self.allocator) catch {
            self.decoded = &.{};
            return;
        };

        self.result_val +%= @as(u32, @intCast(self.decoded.len));
    }

    fn checksum(ctx: *anyopaque) u32 {
        const self: *LZWDecode = @ptrCast(@alignCast(ctx));

        var res = self.result_val;
        if (self.test_data.len > 0 and self.decoded.len > 0) {
            if (std.mem.eql(u8, self.test_data, self.decoded)) {
                res +%= 100000;
            }
        }
        return res;
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *LZWDecode = @ptrCast(@alignCast(ctx));

        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
            self.test_data = &.{};
        }

        if (self.decoded.len > 0) {
            self.allocator.free(self.decoded);
            self.decoded = &.{};
        }

        self.encoded.deinit(self.allocator);

        self.allocator.destroy(self);
    }
};
