const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BWTHuffEncode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    size_val: i64,
    test_data: []u8,
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

    const EncodedResult = struct {
        data: []u8,
        bit_count: u32,

        fn deinit(self: *EncodedResult, allocator: std.mem.Allocator) void {
            if (self.data.len > 0) {
                allocator.free(self.data);
            }
        }
    };

    fn buildSuffixArray(data: []const u8, allocator: std.mem.Allocator) ![]usize {
        const n = data.len;
        if (n == 0) return &.{};

        var sa = try allocator.alloc(usize, n);
        errdefer allocator.free(sa);

        for (0..n) |i| {
            sa[i] = i;
        }

        std.sort.block(usize, sa, data, struct {
            fn lessThan(data_ptr: []const u8, a: usize, b: usize) bool {
                return data_ptr[a] < data_ptr[b];
            }
        }.lessThan);

        if (n > 1) {
            var rank = try allocator.alloc(i32, n * 2);
            defer allocator.free(rank);
            @memset(rank[n..], -1);

            var current_rank: i32 = 0;
            rank[sa[0]] = current_rank;
            for (1..n) |i| {
                if (data[sa[i]] != data[sa[i - 1]]) {
                    current_rank += 1;
                }
                rank[sa[i]] = current_rank;
            }

            var k: usize = 1;
            while (k < n) {

                const SortContext = struct {
                    rank_ptr: []i32,
                    k: usize,

                    fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                        if (ctx.rank_ptr[a] != ctx.rank_ptr[b]) return ctx.rank_ptr[a] < ctx.rank_ptr[b];

                        const n_half = ctx.rank_ptr.len / 2;
                        const rank_a_k = if (a + ctx.k < n_half) ctx.rank_ptr[a + ctx.k] else -1;
                        const rank_b_k = if (b + ctx.k < n_half) ctx.rank_ptr[b + ctx.k] else -1;

                        return rank_a_k < rank_b_k;
                    }
                };

                const context = SortContext{ .rank_ptr = rank, .k = k };
                std.sort.block(usize, sa, context, SortContext.lessThan);

                var new_rank = try allocator.alloc(i32, n);
                defer allocator.free(new_rank);

                current_rank = 0;
                new_rank[sa[0]] = current_rank;

                for (1..n) |i| {
                    const prev = sa[i - 1];
                    const curr = sa[i];

                    const rank_prev1 = rank[prev];
                    const rank_curr1 = rank[curr];
                    const rank_prev2 = if (prev + k < n) rank[prev + k] else -1;
                    const rank_curr2 = if (curr + k < n) rank[curr + k] else -1;

                    if (rank_prev1 != rank_curr1 or rank_prev2 != rank_curr2) {
                        current_rank += 1;
                    }
                    new_rank[curr] = current_rank;
                }

                @memcpy(rank[0..n], new_rank[0..n]);
                k *= 2;
            }
        }

        return sa;
    }

    fn bwtTransform(data: []const u8, allocator: std.mem.Allocator) !BWTResult {
        const n = data.len;
        if (n == 0) return BWTResult{ .transformed = &.{}, .original_idx = 0 };

        const sa = try buildSuffixArray(data, allocator);
        defer allocator.free(sa);

        var transformed = try allocator.alloc(u8, n);
        var original_idx: usize = 0;

        for (0..n) |i| {
            const suffix_idx = sa[i];
            if (suffix_idx == 0) {
                transformed[i] = data[n - 1];
                original_idx = i;
            } else {
                transformed[i] = data[suffix_idx - 1];
            }
        }

        return BWTResult{ .transformed = transformed, .original_idx = original_idx };
    }

    pub const HuffmanNode = struct {
        frequency: u32,
        byte_val: u8,
        is_leaf: bool,
        left: ?*HuffmanNode,
        right: ?*HuffmanNode,
    };

    pub const HuffmanCodes = struct {
        code_lengths: [256]u8,
        codes: [256]u32,
    };

    pub fn buildHuffmanTree(frequencies: []const u32, allocator: std.mem.Allocator) !*HuffmanNode {

        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();

        var heap = std.ArrayList(*HuffmanNode).empty;
        defer heap.deinit(arena_allocator);

        for (0..256) |i| {
            if (frequencies[i] > 0) {
                const node = try arena_allocator.create(HuffmanNode);
                node.* = HuffmanNode{
                    .frequency = frequencies[i],
                    .byte_val = @as(u8, @intCast(i)),
                    .is_leaf = true,
                    .left = null,
                    .right = null,
                };
                try heap.append(arena_allocator, node);
            }
        }

        if (heap.items.len == 1) {
            const leaf = heap.orderedRemove(0);
            const dummy = try arena_allocator.create(HuffmanNode);
            dummy.* = HuffmanNode{
                .frequency = 0,
                .byte_val = 0,
                .is_leaf = true,
                .left = null,
                .right = null,
            };

            const root = try arena_allocator.create(HuffmanNode);
            root.* = HuffmanNode{
                .frequency = leaf.frequency,
                .byte_val = 0,
                .is_leaf = false,
                .left = leaf,
                .right = dummy,
            };

            return root;
        }

        std.sort.block(*HuffmanNode, heap.items, {}, struct {
            fn lessThan(context: void, a: *HuffmanNode, b: *HuffmanNode) bool {
                _ = context;
                return a.frequency < b.frequency;
            }
        }.lessThan);

        while (heap.items.len > 1) {
            const left = heap.orderedRemove(0);
            const right = heap.orderedRemove(0);

            const parent = try arena_allocator.create(HuffmanNode);
            parent.* = HuffmanNode{
                .frequency = left.frequency + right.frequency,
                .byte_val = 0,
                .is_leaf = false,
                .left = left,
                .right = right,
            };

            var insert_idx: usize = 0;
            while (insert_idx < heap.items.len and heap.items[insert_idx].frequency < parent.frequency) {
                insert_idx += 1;
            }
            try heap.insert(arena_allocator, insert_idx, parent);
        }

        return heap.items[0];
    }

    fn buildHuffmanCodes(node: *HuffmanNode, code: u32, length: u8, codes: *HuffmanCodes) void {
        if (node.is_leaf) {

            if (length > 0 or node.byte_val != 0) {
                codes.code_lengths[node.byte_val] = length;
                codes.codes[node.byte_val] = code;
            }
        } else {
            if (node.left) |left| {
                buildHuffmanCodes(left, code << 1, length + 1, codes);
            }
            if (node.right) |right| {
                buildHuffmanCodes(right, (code << 1) | 1, length + 1, codes);
            }
        }
    }

    fn huffmanEncode(data: []const u8, codes: *const HuffmanCodes, allocator: std.mem.Allocator) !EncodedResult {

        var total_bits: u32 = 0;
        for (data) |byte| {
            total_bits += codes.code_lengths[byte];
        }

        const byte_count = (total_bits + 7) / 8;
        var encoded = try allocator.alloc(u8, byte_count);
        @memset(encoded, 0);

        var current_byte: u8 = 0;
        var bit_pos: u8 = 0;
        var byte_idx: usize = 0;

        for (data) |byte| {
            const code = codes.codes[byte];
            const length = codes.code_lengths[byte];

            var remaining_bits = length;
            var code_remaining = code;

            while (remaining_bits > 0) {
                const bits_to_write_u8 = @min(remaining_bits, 8 - bit_pos);
                const bits_to_write = @as(u5, @intCast(bits_to_write_u8));
                const shift_u8 = remaining_bits - bits_to_write_u8;
                const shift = @as(u5, @intCast(shift_u8)); 

                const mask = (@as(u32, 1) << bits_to_write) - 1;
                const bits = (code_remaining >> shift) & mask;

                current_byte |= @as(u8, @truncate(bits)) << @as(u3, @intCast(8 - bit_pos - bits_to_write_u8));
                bit_pos += bits_to_write_u8;
                remaining_bits -= bits_to_write_u8;
                code_remaining &= (@as(u32, 1) << shift) - 1;

                if (bit_pos == 8) {
                    encoded[byte_idx] = current_byte;
                    byte_idx += 1;
                    current_byte = 0;
                    bit_pos = 0;
                }
            }
        }

        if (bit_pos > 0) {
            encoded[byte_idx] = current_byte;
        }

        return EncodedResult{ .data = encoded, .bit_count = total_bits };
    }

    pub const CompressedData = struct {
        bwt_result: BWTResult,
        frequencies: [256]u32,
        encoded_bits: []u8,
        original_bit_count: u32,

        pub fn deinit(self: *CompressedData, allocator: std.mem.Allocator) void {
            self.bwt_result.deinit(allocator);
            if (self.encoded_bits.len > 0) {
                allocator.free(self.encoded_bits);
            }
        }
    };

    pub fn compress(data: []const u8, allocator: std.mem.Allocator) !CompressedData {

        var bwt_result = try bwtTransform(data, allocator);
        defer bwt_result.deinit(allocator); 

        var frequencies: [256]u32 = [_]u32{0} ** 256;
        for (bwt_result.transformed) |byte| {
            frequencies[byte] += 1;
        }

        var tree_arena = std.heap.ArenaAllocator.init(allocator);
        defer tree_arena.deinit(); 
        const tree_allocator = tree_arena.allocator();

        const huffman_tree = try buildHuffmanTree(&frequencies, tree_allocator);

        var huffman_codes = HuffmanCodes{
            .code_lengths = [_]u8{0} ** 256,
            .codes = [_]u32{0} ** 256,
        };
        buildHuffmanCodes(huffman_tree, 0, 0, &huffman_codes);

        var encoded = try huffmanEncode(bwt_result.transformed, &huffman_codes, allocator);
        defer encoded.deinit(allocator); 

        const bwt_copy = try allocator.dupe(u8, bwt_result.transformed);
        const encoded_copy = try allocator.dupe(u8, encoded.data);

        return CompressedData{
            .bwt_result = .{ .transformed = bwt_copy, .original_idx = bwt_result.original_idx },
            .frequencies = frequencies,
            .encoded_bits = encoded_copy,
            .original_bit_count = encoded.bit_count,
        };
    }

    pub fn generateTestData(size: i64, allocator: std.mem.Allocator) ![]u8 {
        const pattern = "ABRACADABRA";
        var data = try allocator.alloc(u8, @as(usize, @intCast(size)));
        for (0..@as(usize, @intCast(size))) |i| {
            data[i] = pattern[i % pattern.len];
        }
        return data;
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BWTHuffEncode {
        const size = helper.config_i64("BWTHuffEncode", "size");
        const self = try allocator.create(BWTHuffEncode);
        self.* = BWTHuffEncode{
            .allocator = allocator,
            .helper = helper,
            .size_val = size,
            .test_data = &.{},
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BWTHuffEncode) void {
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BWTHuffEncode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "BWTHuffEncode");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *BWTHuffEncode = @ptrCast(@alignCast(ptr));
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        self.test_data = generateTestData(self.size_val, self.allocator) catch &.{};
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *BWTHuffEncode = @ptrCast(@alignCast(ptr));

        var compressed = compress(self.test_data, self.allocator) catch return;
        defer compressed.deinit(self.allocator);

        self.result_val +%= @as(u32, @intCast(compressed.encoded_bits.len));
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BWTHuffEncode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BWTHuffEncode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};