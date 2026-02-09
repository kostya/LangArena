const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Base64Decode = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    encoded: []const u8,
    decoded: []u8,
    decoded_from_run: []u8,  
    result_val: u32,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Base64Decode {
        const size = helper.config_i64("Base64Decode", "size");
        const self = try allocator.create(Base64Decode);
        errdefer allocator.destroy(self);

        const input_len = @as(usize, @intCast(size));
        const input_str = try allocator.alloc(u8, input_len);
        @memset(input_str, 'a');

        const encoder = std.base64.standard.Encoder;
        const encoded_len = encoder.calcSize(input_len);
        const encoded_buf = try allocator.alloc(u8, encoded_len);
        const encoded_result = encoder.encode(encoded_buf, input_str);

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

        allocator.free(input_str);

        self.* = Base64Decode{
            .allocator = allocator,
            .helper = helper,
            .encoded = encoded_result,
            .decoded = decoded_buf,
            .decoded_from_run = &.{},  
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Base64Decode) void {

        if (self.decoded_from_run.len > 0) {
            self.allocator.free(self.decoded_from_run);
        }

        const encoded_buf = self.encoded.ptr[0..std.base64.standard.Encoder.calcSize(self.decoded.len)];
        self.allocator.free(encoded_buf);

        self.allocator.free(self.decoded);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Base64Decode) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Base64Decode");
    }

    fn prepareImpl(_: *anyopaque) void {
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));
        const decoder = std.base64.standard.Decoder;

        const decode_buf_size = decoder.calcSizeForSlice(self.encoded) catch {
            self.result_val = 0;
            return;
        };

        if (self.decoded_from_run.len > 0) {
            self.allocator.free(self.decoded_from_run);
        }

        const decode_buf = self.allocator.alloc(u8, decode_buf_size) catch {
            self.result_val = 0;
            self.decoded_from_run = &.{};
            return;
        };

        decoder.decode(decode_buf, self.encoded) catch {
            self.allocator.free(decode_buf);
            self.result_val = 0;
            self.decoded_from_run = &.{};
            return;
        };

        self.decoded_from_run = decode_buf;

        self.result_val +%= @as(u32, @intCast(decode_buf_size));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));
        var result_buf: [256]u8 = undefined;

        const first_four_encoded = if (self.encoded.len >= 4) self.encoded[0..4] else self.encoded;

        const actual_decoded = if (self.decoded_from_run.len > 0) self.decoded_from_run else self.decoded;
        const first_four_decoded = if (actual_decoded.len >= 4) actual_decoded[0..4] else actual_decoded;

        const result_str = std.fmt.bufPrint(
            &result_buf,
            "decode {s}... to {s}...: {}",
            .{ 
                if (self.encoded.len > 4) first_four_encoded else first_four_encoded,
                if (actual_decoded.len > 4) first_four_decoded else first_four_decoded,
                self.result_val 
            }
        ) catch "decode error";

        return self.helper.checksumString(result_str);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Base64Decode = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};