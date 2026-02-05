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
        // Шаг 1: Восстанавливаем дерево Хаффмана
        var tree_arena = std.heap.ArenaAllocator.init(allocator);
        defer tree_arena.deinit();
        const tree_allocator = tree_arena.allocator();

        const huffman_tree = try BWTHuffEncode.buildHuffmanTree(&compressed.frequencies, tree_allocator);

        // Шаг 2: Декодирование Хаффмана
        const decoded = try huffmanDecode(compressed.encoded_bits, huffman_tree, compressed.original_bit_count, allocator);
        defer allocator.free(decoded);

        // Шаг 3: Обратное BWT преобразование
        const bwt_result = BWTHuffEncode.BWTResult{
            .transformed = decoded,
            .original_idx = compressed.bwt_result.original_idx,
        };
        const result = try bwtInverse(bwt_result, allocator);

        return result;
    }

    // Функции декомпрессии можно либо взять из Compression, если они там есть,
    // либо реализовать здесь
    fn huffmanDecode(encoded: []const u8, root: *BWTHuffEncode.HuffmanNode, bit_count: u32, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).empty;
        defer result.deinit(allocator);

        var current_node = root;
        var bits_processed: u32 = 0;
        var byte_idx: usize = 0;

        while (bits_processed < bit_count and byte_idx < encoded.len) {
            const byte_val = encoded[byte_idx];
            byte_idx += 1;

            // Читаем биты слева направо (старший бит first)
            var bit_pos: u32 = 8;
            while (bit_pos > 0 and bits_processed < bit_count) {
                bit_pos -= 1;
                bits_processed += 1;

                const bit = (byte_val >> @as(u3, @intCast(bit_pos))) & 1;

                // Переходим по дереву
                current_node = if (bit == 1)
                    current_node.right.?
                else
                    current_node.left.?;

                // Если достигли листа
                if (current_node.is_leaf) {
                    // Игнорируем фиктивный символ (byte_val == 0)
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

        // Подсчитываем частоты символов
        var counts: [256]usize = [_]usize{0} ** 256;
        for (bwt) |byte| {
            counts[byte] += 1;
        }

        // Вычисляем стартовые позиции
        var positions: [256]usize = [_]usize{0} ** 256;
        var total: usize = 0;
        for (0..256) |i| {
            positions[i] = total;
            total += counts[i];
        }

        // Строим LF-маппинг
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

        // Восстанавливаем исходную строку
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

        // Освобождаем предыдущие данные
        if (self.test_data.len > 0) {
            self.allocator.free(self.test_data);
        }
        if (self.compressed_data) |*compressed| {
            compressed.deinit(self.allocator);
        }
        if (self.decompressed.len > 0) {
            self.allocator.free(self.decompressed);
        }

        // Генерируем тестовые данные
        self.test_data = BWTHuffEncode.generateTestData(self.size_val, self.allocator) catch &.{};

        // Сжимаем данные через статическую функцию
        self.compressed_data = BWTHuffEncode.compress(self.test_data, self.allocator) catch null;
        self.decompressed = &.{};
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));

        // Проверяем, что есть сжатые данные
        if (self.compressed_data) |*compressed| {
            // Распаковываем
            const decompressed = decompress(compressed, self.allocator) catch return;

            // Освобождаем предыдущие распакованные данные
            if (self.decompressed.len > 0) {
                self.allocator.free(self.decompressed);
            }

            self.decompressed = decompressed;

            // Добавляем размер распакованных данных как в C++ версии
            self.result_val +%= @as(u32, @intCast(self.decompressed.len));
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BWTHuffDecode = @ptrCast(@alignCast(ptr));

        var res = self.result_val;

        // Проверяем корректность декомпрессии как в C++ версии
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