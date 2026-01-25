// src/base64decode.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Base64Decode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    encoded: []const u8,
    decoded: []u8,
    result_val: u32,

    const TRIES: i32 = 8192;
    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Base64Decode {
        const n = helper.getInputInt("Base64Decode");

        const self = try allocator.create(Base64Decode);
        errdefer allocator.destroy(self);

        // Создаем входную строку из 'a' * n
        const input_len = @as(usize, @intCast(n));
        const input_str = try allocator.alloc(u8, input_len);
        @memset(input_str, 'a');

        // Кодируем её
        const encoder = std.base64.standard.Encoder;
        const encoded_len = encoder.calcSize(input_len);
        const encoded_buf = try allocator.alloc(u8, encoded_len);
        const encoded_result = encoder.encode(encoded_buf, input_str);

        // Декодируем обратно для проверки (храним результат)
        const decoder = std.base64.standard.Decoder;
        const decoded_len = decoder.calcSizeForSlice(encoded_result) catch {
            allocator.free(input_str);
            allocator.free(encoded_buf);
            return error.DecodeError;
        };

        const decoded_buf = try allocator.alloc(u8, decoded_len);
        decoder.decode(decoded_buf, encoded_result) catch {
            allocator.free(input_str);
            allocator.free(encoded_buf);
            allocator.free(decoded_buf);
            return error.DecodeError;
        };

        // Освобождаем временный input
        allocator.free(input_str);

        self.* = Base64Decode{
            .allocator = allocator,
            .helper = helper,
            .encoded = encoded_result,
            .decoded = decoded_buf,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Base64Decode) void {
        // Освобождаем encoded буфер
        const encoded_buf_len = std.base64.standard.Encoder.calcSize(self.decoded.len);
        const encoded_buf = self.encoded.ptr[0..encoded_buf_len];
        self.allocator.free(encoded_buf);

        // Освобождаем decoded буфер
        self.allocator.free(self.decoded);

        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Base64Decode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));

        var total_decoded: i64 = 0;
        const decoder = std.base64.standard.Decoder;

        // Вычисляем размер буфера для декодирования
        const decode_buf_size = decoder.calcSizeForSlice(self.encoded) catch 0;
        if (decode_buf_size == 0) return;

        // Выделяем буфер для декодирования
        const decode_buf = self.allocator.alloc(u8, decode_buf_size) catch return;
        defer self.allocator.free(decode_buf);

        for (0..TRIES) |_| {
            decoder.decode(decode_buf, self.encoded) catch break;
            total_decoded += @as(i64, @intCast(decode_buf_size));
        }

        // Формируем строку результата как в C++
        const first_four_encoded = if (self.encoded.len >= 4) self.encoded[0..4] else self.encoded;
        const first_four_decoded = if (self.decoded.len >= 4) self.decoded[0..4] else self.decoded;

        var result_buf: [256]u8 = undefined;
        const result_str = std.fmt.bufPrint(&result_buf, "decode {s}... to {s}...: {}\n", .{ first_four_encoded, first_four_decoded, total_decoded }) catch "decode error\n";

        self.result_val = self.helper.checksumString(result_str);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
