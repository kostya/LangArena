const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Mandelbrot = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    w: i64,
    h: i64,
    result_bin: std.ArrayList(u8),

    const ITER: i32 = 50;
    const LIMIT: f64 = 2.0;

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
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
            .result_bin = std.ArrayList(u8){},
        };

        return self;
    }

    pub fn deinit(self: *Mandelbrot) void {
        self.result_bin.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Mandelbrot) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Mandelbrot");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));

        self.result_bin.clearAndFree(self.allocator);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));
        const w = @as(i32, @intCast(self.w));
        const h = @as(i32, @intCast(self.h));

        if (w <= 0 or h <= 0) {
            return;
        }

        var header_buf: [64]u8 = undefined;
        const header_str = std.fmt.bufPrint(&header_buf, "P4\n{d} {d}\n", .{ w, h }) catch return;
        self.result_bin.appendSlice(self.allocator, header_str) catch return;

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
                    self.result_bin.append(self.allocator, byte_acc) catch return;
                    byte_acc = 0;
                    bit_num = 0;
                } else if (x == w - 1) {
                    const remaining_bits = 8 - @as(i32, @intCast(@mod(w, 8)));
                    if (remaining_bits < 8) {
                        byte_acc <<= @as(u3, @intCast(remaining_bits));
                    }
                    self.result_bin.append(self.allocator, byte_acc) catch return;
                    byte_acc = 0;
                    bit_num = 0;
                }
            }
        }

        if (bit_num > 0) {
            byte_acc <<= @as(u3, @intCast(8 - bit_num));
            self.result_bin.append(self.allocator, byte_acc) catch return;
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));

        return self.helper.checksumBytes(self.result_bin.items);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Mandelbrot = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
