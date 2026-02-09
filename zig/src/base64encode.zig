const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Base64Encode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    input: []const u8,
    encoded: []const u8,
    encoded_from_run: []const u8,  
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Base64Encode {
        const size = helper.config_i64("Base64Encode", "size");
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
            .encoded_from_run = &.{},  
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Base64Encode) void {

        if (self.encoded_from_run.len > 0) {
            const buf_len = std.base64.standard.Encoder.calcSize(self.input.len);
            const buf = self.encoded_from_run.ptr[0..buf_len];
            self.allocator.free(buf);
        }

        self.allocator.free(self.input);
        const encoded_buf_len = std.base64.standard.Encoder.calcSize(self.input.len);
        const encoded_buf = self.encoded.ptr[0..encoded_buf_len];
        self.allocator.free(encoded_buf);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Base64Encode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Base64Encode");
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        const encoder = std.base64.standard.Encoder;

        const encode_buf_size = encoder.calcSize(self.input.len);

        if (self.encoded_from_run.len > 0) {
            const prev_buf_len = std.base64.standard.Encoder.calcSize(self.input.len);
            const prev_buf = self.encoded_from_run.ptr[0..prev_buf_len];
            self.allocator.free(prev_buf);
        }

        const encode_buf = self.allocator.alloc(u8, encode_buf_size) catch {
            self.result_val = 0;
            self.encoded_from_run = &.{};
            return;
        };

        const encoded_result = encoder.encode(encode_buf, self.input);

        self.encoded_from_run = encoded_result;

        self.result_val +%= @as(u32, @intCast(encoded_result.len));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        var result_buf: [256]u8 = undefined;

        const first_four_input = if (self.input.len >= 4) self.input[0..4] else self.input;

        const actual_encoded = if (self.encoded_from_run.len > 0) self.encoded_from_run else self.encoded;
        const first_four_encoded = if (actual_encoded.len >= 4) actual_encoded[0..4] else actual_encoded;

        const result_str = std.fmt.bufPrint(
            &result_buf,
            "encode {s}... to {s}...: {}",
            .{ 
                if (self.input.len > 4) first_four_input else first_four_input,
                if (actual_encoded.len > 4) first_four_encoded else first_four_encoded,
                self.result_val 
            }
        ) catch "encode error";

        return self.helper.checksumString(result_str);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Base64Encode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};