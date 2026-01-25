// src/base64encode.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Base64Encode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    input: []const u8,
    encoded: []const u8,
    result_val: u32,

    const TRIES: i32 = 8192;
    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Base64Encode {
        const n = helper.getInputInt("Base64Encode");

        const self = try allocator.create(Base64Encode);
        errdefer allocator.destroy(self);

        // Создаем входную строку из 'a' * n
        const input_str = try allocator.alloc(u8, @as(usize, @intCast(n)));
        @memset(input_str, 'a');

        // Вычисляем размер закодированной строки
        const encoded_len = std.base64.standard.Encoder.calcSize(input_str.len);
        const encoded_buf = try allocator.alloc(u8, encoded_len);

        // Кодируем для проверки (encode возвращает slice)
        const encoded_result = std.base64.standard.Encoder.encode(encoded_buf, input_str);

        self.* = Base64Encode{
            .allocator = allocator,
            .helper = helper,
            .input = input_str,
            .encoded = encoded_result,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Base64Encode) void {
        self.allocator.free(self.input);
        // encoded это slice, освобождаем оригинальный буфер
        const encoded_buf_len = std.base64.standard.Encoder.calcSize(self.input.len);
        const encoded_buf = self.encoded.ptr[0..encoded_buf_len];
        self.allocator.free(encoded_buf);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Base64Encode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // src/base64encode.zig - финальная версия runImpl
    fn runImpl(ptr: *anyopaque) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));

        var total_encoded: i64 = 0;
        const encoder = std.base64.standard.Encoder;

        // Буфер для кодирования
        const encode_buf_size = encoder.calcSize(self.input.len);
        const encode_buf = self.allocator.alloc(u8, encode_buf_size) catch return;
        defer self.allocator.free(encode_buf);

        for (0..TRIES) |_| {
            const encoded_result = encoder.encode(encode_buf, self.input);
            total_encoded += @as(i64, @intCast(encoded_result.len));
        }

        // Формируем строку результата с bufPrint
        const first_four_input = if (self.input.len >= 4) self.input[0..4] else self.input;
        const first_four_encoded = if (self.encoded.len >= 4) self.encoded[0..4] else self.encoded;

        var result_buf: [256]u8 = undefined;
        const result_str = std.fmt.bufPrint(&result_buf, "encode {s}... to {s}...: {}\n", .{ first_four_input, first_four_encoded, total_encoded }) catch "encode error\n";

        self.result_val = self.helper.checksumString(result_str);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
