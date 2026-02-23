const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Base64Encode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    input: []const u8,
    encoded: []const u8,
    encoded_size: usize,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Base64Encode {
        const size = helper.config_i64("Base64::Encode", "size");
        const self = try allocator.create(Base64Encode);
        errdefer allocator.destroy(self);

        const input_str = try allocator.alloc(u8, @as(usize, @intCast(size)));
        @memset(input_str, 'a');

        const encoder = std.base64.standard.Encoder;
        const encoded_len = encoder.calcSize(input_str.len);
        const encoded_buf = try allocator.alloc(u8, encoded_len);
        const encoded_result = encoder.encode(encoded_buf, input_str);

        self.* = Base64Encode{
            .allocator = allocator,
            .helper = helper,
            .input = input_str,
            .encoded = encoded_result,
            .encoded_size = encoded_len,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Base64Encode) void {
        if (self.encoded.len > 0) {
            const buf = self.encoded.ptr[0..self.encoded_size];
            self.allocator.free(buf);
        }

        self.allocator.free(self.input);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Base64Encode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Base64::Encode");
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        const encoder = std.base64.standard.Encoder;

        const encode_buf_size = encoder.calcSize(self.input.len);

        if (self.encoded.len > 0) {
            const prev_buf = self.encoded.ptr[0..self.encoded_size];
            self.allocator.free(prev_buf);
        }

        const encode_buf = self.allocator.alloc(u8, encode_buf_size) catch {
            self.result_val = 0;
            self.encoded = &.{};
            return;
        };

        const encoded_result = encoder.encode(encode_buf, self.input);
        self.encoded = encoded_result;
        self.encoded_size = encode_buf_size;

        self.result_val +%= @as(u32, @intCast(encoded_result.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        var result_buf: [256]u8 = undefined;

        const first_four_input = if (self.input.len >= 4) self.input[0..4] else self.input;

        const actual_encoded = self.encoded;
        const first_four_encoded = if (actual_encoded.len >= 4) actual_encoded[0..4] else actual_encoded;

        const result_str = std.fmt.bufPrint(&result_buf, "encode {s}... to {s}...: {}", .{ if (self.input.len > 4) first_four_input else first_four_input, if (actual_encoded.len > 4) first_four_encoded else first_four_encoded, self.result_val }) catch "encode error";

        return self.helper.checksumString(result_str);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
