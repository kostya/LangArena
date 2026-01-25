// src/compression.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const mem = std.mem;
const sort = std.sort;

pub const Compression = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    iterations: u32,
    test_data: []u8,
    result_val: u64,

    // ==================== BWT ====================
    const BWTResult = struct {
        transformed: []u8,
        original_idx: usize,

        pub fn deinit(self: *BWTResult, allocator: std.mem.Allocator) void {
            allocator.free(self.transformed);
        }
    };

    // Точная копия C++ алгоритма построения суффиксного массива
    fn buildSuffixArray(data: []const u8, allocator: std.mem.Allocator) ![]usize {
        const n = data.len;
        if (n == 0) return &.{};

        // 1. Создаём удвоенную строку как в C++
        var doubled = try allocator.alloc(u8, n * 2);
        defer allocator.free(doubled);

        @memcpy(doubled[0..n], data);
        @memcpy(doubled[n..], data);

        // 2. Создаём суффиксный массив для первых n позиций
        var sa = try allocator.alloc(usize, n);
        errdefer allocator.free(sa);

        for (0..n) |i| {
            sa[i] = i;
        }

        // 3. Фаза 0: сортировка по первому символу (Radix sort) - как в C++
        var buckets: [256]std.ArrayList(usize) = undefined;
        for (&buckets) |*bucket| {
            bucket.* = std.ArrayList(usize).empty;
        }
        defer for (&buckets) |*bucket| {
            bucket.deinit(allocator);
        };

        for (sa) |idx| {
            try buckets[data[idx]].append(allocator, idx);
        }

        var pos: usize = 0;
        for (&buckets) |*bucket| {
            for (bucket.items) |idx| {
                sa[pos] = idx;
                pos += 1;
            }
        }

        // 4. Фаза 1: сортировка по парам символов - как в C++
        if (n > 1) {
            // Присваиваем ранги по первому символу
            var rank = try allocator.alloc(i32, n);
            defer allocator.free(rank);

            var current_rank: i32 = 0;
            var prev_char = data[sa[0]];

            for (0..n) |i| {
                const idx = sa[i];
                const curr_char = data[idx];
                if (curr_char != prev_char) {
                    current_rank += 1;
                    prev_char = curr_char;
                }
                rank[idx] = current_rank;
            }

            // Сортируем по парам (ранг[i], ранг[i+1])
            var k: usize = 1;
            while (k < n) {
                // Создаём пары для сортировки
                var pairs = try allocator.alloc(struct { i32, i32 }, n);
                defer allocator.free(pairs);

                for (0..n) |i| {
                    pairs[i] = .{ rank[i], rank[(i + k) % n] };
                }

                // Сортируем индексы по парам
                sort.block(usize, sa, pairs, struct {
                    fn lessThan(pairs_ptr: []const struct { i32, i32 }, a: usize, b: usize) bool {
                        const pair_a = pairs_ptr[a];
                        const pair_b = pairs_ptr[b];

                        if (pair_a[0] != pair_b[0]) {
                            return pair_a[0] < pair_b[0];
                        }
                        return pair_a[1] < pair_b[1];
                    }
                }.lessThan);

                // Обновляем ранги
                var new_rank = try allocator.alloc(i32, n);
                defer allocator.free(new_rank);

                new_rank[sa[0]] = 0;
                for (1..n) |i| {
                    const prev_pair = pairs[sa[i - 1]];
                    const curr_pair = pairs[sa[i]];

                    new_rank[sa[i]] = new_rank[sa[i - 1]] +
                        @intFromBool(!std.mem.eql(i32, &prev_pair, &curr_pair));
                }

                @memcpy(rank, new_rank);
                k *= 2;
            }
        }

        return sa;
    }

    fn bwtTransform(data: []const u8, allocator: std.mem.Allocator) !BWTResult {
        const n = data.len;
        if (n == 0) {
            return BWTResult{ .transformed = &.{}, .original_idx = 0 };
        }

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

    fn bwtInverse(bwt_result: BWTResult, allocator: std.mem.Allocator) ![]u8 {
        const bwt = bwt_result.transformed;
        const n = bwt.len;
        if (n == 0) {
            return &.{};
        }

        // 1. Подсчитываем частоты символов - как в C++
        var counts: [256]usize = [_]usize{0} ** 256;
        for (bwt) |byte| {
            counts[byte] += 1;
        }

        // 2. Вычисляем стартовые позиции в первом столбце - как в C++
        var positions: [256]usize = [_]usize{0} ** 256;
        var total: usize = 0;
        for (0..256) |i| {
            positions[i] = total;
            total += counts[i];
        }

        // 3. Строим массив next (LF-маппинг) - ТОЧНО как в C++
        var next = try allocator.alloc(usize, n);
        defer allocator.free(next);
        @memset(next, 0);

        var temp_counts: [256]usize = [_]usize{0} ** 256;

        for (0..n) |i| {
            const byte = bwt[i];
            const pos = positions[byte] + temp_counts[byte];
            next[pos] = i; // ТОЧНО как в C++: next[pos] = i
            temp_counts[byte] += 1;
        }

        // 4. Восстанавливаем исходную строку - как в C++
        var result = try allocator.alloc(u8, n);
        var idx = bwt_result.original_idx;

        for (0..n) |i| {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

    // ==================== Huffman ====================
    const HuffmanNode = struct {
        frequency: u32,
        byte_val: u8,
        is_leaf: bool,
        left: ?*HuffmanNode,
        right: ?*HuffmanNode,

        pub fn initLeaf(frequency: u32, byte_val: u8) HuffmanNode {
            return HuffmanNode{
                .frequency = frequency,
                .byte_val = byte_val,
                .is_leaf = true,
                .left = null,
                .right = null,
            };
        }

        pub fn initInternal(frequency: u32, left: *HuffmanNode, right: *HuffmanNode) HuffmanNode {
            return HuffmanNode{
                .frequency = frequency,
                .byte_val = 0,
                .is_leaf = false,
                .left = left,
                .right = right,
            };
        }
    };

    const HuffmanCodes = struct {
        code_lengths: [256]u8,
        codes: [256]u32,

        pub fn init() HuffmanCodes {
            return .{
                .code_lengths = [_]u8{0} ** 256,
                .codes = [_]u32{0} ** 256,
            };
        }
    };

    // ТОЧНО как в C++: build_huffman_tree
    fn buildHuffmanTree(frequencies: []const u32, allocator: std.mem.Allocator) !*HuffmanNode {
        var heap = std.PriorityQueue(*HuffmanNode, void, struct {
            fn lessThan(context: void, a: *HuffmanNode, b: *HuffmanNode) std.math.Order {
                _ = context;
                // ТОЧНО как в C++: min-heap по частоте
                return std.math.order(a.frequency, b.frequency);
            }
        }.lessThan).init(allocator, {});
        defer heap.deinit();

        // Создаем arena для узлов дерева (аналог shared_ptr в C++)
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();

        // Добавляем все символы с ненулевой частотой - как в C++
        for (0..256) |i| {
            if (frequencies[i] > 0) {
                const node = try arena_allocator.create(HuffmanNode);
                node.* = HuffmanNode.initLeaf(frequencies[i], @as(u8, @intCast(i)));
                try heap.add(node);
            }
        }

        // Если только один символ - ТОЧНО как в C++
        if (heap.count() == 1) {
            const leaf = heap.remove();
            const dummy = try arena_allocator.create(HuffmanNode);
            dummy.* = HuffmanNode.initLeaf(0, 0);

            const root = try arena_allocator.create(HuffmanNode);
            root.* = HuffmanNode.initInternal(leaf.frequency, leaf, dummy);

            // arena продолжает жить (аналог shared_ptr)
            // _ = arena;
            return root;
        }

        // Строим дерево - ТОЧНО как в C++
        while (heap.count() > 1) {
            const left = heap.remove();
            const right = heap.remove();

            const parent = try arena_allocator.create(HuffmanNode);
            parent.* = HuffmanNode.initInternal(left.frequency + right.frequency, left, right);

            try heap.add(parent);
        }

        const root = heap.remove();
        // arena продолжает жить (аналог shared_ptr)
        // _ = arena;
        return root;
    }

    // ТОЧНО как в C++: build_huffman_codes
    fn buildHuffmanCodes(node: *HuffmanNode, code: u32, length: u8, codes: *HuffmanCodes) void {
        if (node.is_leaf) {
            // Игнорируем фиктивный символ (byte_val == 0) - как в C++
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

    const EncodedResult = struct {
        data: []u8,
        bit_count: u32,

        pub fn deinit(self: *EncodedResult, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
    };

    // ТОЧНО как в C++: huffman_encode
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

            if (length == 0) continue;

            // Копируем биты из code - как в C++
            for (0..length) |i| {
                const shift = @as(u5, @intCast(length - 1 - i)); // Старший бит first
                const bit = (code >> shift) & 1;

                current_byte |= @as(u8, @truncate(bit)) << @as(u3, @intCast(7 - bit_pos));
                bit_pos += 1;

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

    // ТОЧНО как в C++: huffman_decode
    fn huffmanDecode(encoded: []const u8, root: *HuffmanNode, bit_count: u32, allocator: std.mem.Allocator) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(allocator);

        var current_node = root;
        var bits_processed: u32 = 0;
        var byte_idx: usize = 0;

        while (bits_processed < bit_count and byte_idx < encoded.len) {
            const byte_val = encoded[byte_idx];
            byte_idx += 1;

            // Читаем биты слева направо (старший бит first) - как в C++
            var bit_pos: u32 = 8;
            while (bit_pos > 0 and bits_processed < bit_count) {
                bit_pos -= 1;
                bits_processed += 1;

                const bit = (byte_val >> @as(u3, @intCast(bit_pos))) & 1;

                // Переходим по дереву - как в C++
                current_node = if (bit == 1)
                    current_node.right.?
                else
                    current_node.left.?;

                // Если достигли листа - как в C++
                if (current_node.is_leaf) {
                    // Игнорируем фиктивный символ (byte_val == 0) - как в C++
                    if (current_node.byte_val != 0) {
                        try result.append(allocator, current_node.byte_val);
                    }
                    current_node = root;
                }
            }
        }

        return result.toOwnedSlice(allocator);
    }

    // ==================== Основная структура ====================
    const CompressedData = struct {
        bwt_result: BWTResult,
        frequencies: [256]u32,
        encoded_bits: []u8,
        original_bit_count: u32,

        pub fn deinit(self: *CompressedData, allocator: std.mem.Allocator) void {
            self.bwt_result.deinit(allocator);
            allocator.free(self.encoded_bits);
        }
    };

    // ТОЧНО как в C++: compress
    fn compress(data: []const u8, allocator: std.mem.Allocator) !CompressedData {
        // Используем arena для временных данных
        var compress_arena = std.heap.ArenaAllocator.init(allocator);
        defer compress_arena.deinit();
        const compress_allocator = compress_arena.allocator();

        // 1. BWT преобразование - как в C++
        const bwt_result = try bwtTransform(data, compress_allocator);
        var bwt_result_var = bwt_result;
        defer bwt_result_var.deinit(compress_allocator);

        // 2. Подсчёт частот - как в C++
        var frequencies: [256]u32 = [_]u32{0} ** 256;
        for (bwt_result.transformed) |byte| {
            frequencies[byte] += 1;
        }

        // 3. Построение дерева Huffman - как в C++
        var tree_arena = std.heap.ArenaAllocator.init(allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        const huffman_tree = try buildHuffmanTree(&frequencies, tree_allocator);

        // 4. Построение кодов - как в C++
        var huffman_codes = HuffmanCodes.init();
        buildHuffmanCodes(huffman_tree, 0, 0, &huffman_codes);

        // 5. Кодирование Huffman - как в C++
        var encoded = try huffmanEncode(bwt_result.transformed, &huffman_codes, compress_allocator);
        defer encoded.deinit(compress_allocator);

        // 6. Копируем данные для возврата
        const bwt_copy = try allocator.dupe(u8, bwt_result.transformed);
        const encoded_copy = try allocator.dupe(u8, encoded.data);

        return CompressedData{
            .bwt_result = .{ .transformed = bwt_copy, .original_idx = bwt_result.original_idx },
            .frequencies = frequencies,
            .encoded_bits = encoded_copy,
            .original_bit_count = encoded.bit_count,
        };
    }

    // ТОЧНО как в C++: decompress
    fn decompress(compressed: *const CompressedData, allocator: std.mem.Allocator) ![]u8 {
        // Создаем arena для дерева Huffman
        var tree_arena = std.heap.ArenaAllocator.init(allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        // 1. Восстанавливаем дерево Huffman - как в C++
        const huffman_tree = try buildHuffmanTree(&compressed.frequencies, tree_allocator);

        // 2. Декодирование Huffman - как в C++
        var decode_arena = std.heap.ArenaAllocator.init(allocator);
        defer decode_arena.deinit();
        const decode_allocator = decode_arena.allocator();

        const decoded = try huffmanDecode(compressed.encoded_bits, huffman_tree, compressed.original_bit_count, decode_allocator);

        // 3. Обратное BWT преобразование - как в C++
        const bwt_result = BWTResult{ .transformed = decoded, .original_idx = compressed.bwt_result.original_idx };
        const result = try bwtInverse(bwt_result, allocator);

        // 4. Освобождаем временные данные
        decode_allocator.free(decoded);

        return result;
    }

    // ==================== Бенчмарк ====================
    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    fn generateTestData(size: usize, allocator: std.mem.Allocator) ![]u8 {
        const pattern = "ABRACADABRA";
        var data = try allocator.alloc(u8, size);

        for (0..size) |i| {
            data[i] = pattern[i % pattern.len];
        }

        return data;
    }

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Compression {
        const data_size = helper.getInputInt("Compression");
        const size: u32 = @intCast(if (data_size > 0) data_size else 10000);

        const self = try allocator.create(Compression);
        self.* = Compression{
            .allocator = allocator,
            .helper = helper,
            .iterations = size,
            .test_data = &.{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Compression) void {
        self.allocator.free(self.test_data);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Compression) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Compression = @ptrCast(@alignCast(ptr));
        self.test_data = generateTestData(self.iterations, self.allocator) catch return;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Compression = @ptrCast(@alignCast(ptr));
        var total_checksum: u32 = 0;

        for (0..5) |_| {
            var compressed = compress(self.test_data, self.allocator) catch return;
            defer compressed.deinit(self.allocator);

            const decompressed = decompress(&compressed, self.allocator) catch return;
            defer self.allocator.free(decompressed);

            if (!mem.eql(u8, self.test_data, decompressed)) {
                return;
            }

            const checksum = self.helper.checksumBytes(decompressed);
            total_checksum = (total_checksum +% @as(u32, @truncate(compressed.encoded_bits.len))) & 0xFFFFFFFF;
            total_checksum = (total_checksum +% checksum) & 0xFFFFFFFF;
        }

        self.result_val = total_checksum;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Compression = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Compression = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
