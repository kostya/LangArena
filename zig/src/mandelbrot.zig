const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Mandelbrot = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    w: i64,
    h: i64,
    result_val: u32,

    const ITER: i32 = 50;
    const LIMIT: f64 = 2.0;

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Mandelbrot {
        const w = helper.config_i64("Mandelbrot", "w");
        const h = helper.config_i64("Mandelbrot", "h");

        const self = try allocator.create(Mandelbrot);
        errdefer allocator.destroy(self);

        self.* = Mandelbrot{
            .allocator = allocator,
            .helper = helper,
            .w = w,
            .h = h,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Mandelbrot) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Mandelbrot) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));
        const w = @as(i32, @intCast(self.w));
        const h = @as(i32, @intCast(self.h));

        if (w <= 0 or h <= 0) {
            const checksum = self.helper.checksumBytes(&.{});
            self.result_val = checksum;
            return;
        }

        var header_buf: [64]u8 = undefined;
        const header_len = (std.fmt.bufPrint(&header_buf, "P4\n{d} {d}\n", .{ w, h }) catch return).len;

        const w_usize = @as(usize, @intCast(w));
        const h_usize = @as(usize, @intCast(h));
        const bytes_per_row = @divFloor(w_usize + 7, 8);
        const total_bytes = header_len + bytes_per_row * h_usize;

        var result = std.ArrayList(u8).initCapacity(self.allocator, total_bytes) catch return;
        defer result.deinit(self.allocator);

        result.appendSliceAssumeCapacity(header_buf[0..header_len]);

        var byte_acc: u8 = 0;
        var bit_num: i32 = 0;
        const w_f64 = @as(f64, @floatFromInt(w));
        const h_f64 = @as(f64, @floatFromInt(h));
        const limit_sq = LIMIT * LIMIT;

        var y: i32 = 0;
        while (y < h) : (y += 1) {
            var x: i32 = 0;
            while (x < w) : (x += 1) {
                const cr = 2.0 * @as(f64, @floatFromInt(x)) / w_f64 - 1.5;
                const ci = 2.0 * @as(f64, @floatFromInt(y)) / h_f64 - 1.0;

                var zr: f64 = 0.0;
                var zi: f64 = 0.0;
                var tr: f64 = 0.0;
                var ti: f64 = 0.0;

                var i: i32 = 0;
                while (i < ITER and tr + ti <= limit_sq) {
                    zi = 2.0 * zr * zi + ci;
                    zr = tr - ti + cr;
                    tr = zr * zr;
                    ti = zi * zi;
                    i += 1;
                }

                byte_acc <<= 1;
                if (tr + ti <= limit_sq) {
                    byte_acc |= 0x01;
                }
                bit_num += 1;

                if (bit_num == 8) {
                    result.appendAssumeCapacity(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                } else if (x == w - 1) {
                    const remaining_bits = 8 - @as(i32, @intCast(@mod(w, 8)));
                    if (remaining_bits < 8) {
                        byte_acc <<= @as(u3, @intCast(remaining_bits));
                    }
                    result.appendAssumeCapacity(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                }
            }
        }

        if (bit_num > 0) {
            byte_acc <<= @as(u3, @intCast(8 - bit_num));
            result.appendAssumeCapacity(byte_acc);
        }

        self.result_val = self.helper.checksumBytes(result.items);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};