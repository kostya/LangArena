const std = @import("std");
const c = @cImport({
    @cInclude("gmp.h");
});
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Pidigits = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    nn: i32,
    result_str: std.ArrayListUnmanaged(u8),

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Pidigits {
        const nn = helper.config_i64("Pidigits", "amount");

        const self = try allocator.create(Pidigits);
        errdefer allocator.destroy(self);

        self.* = Pidigits{
            .allocator = allocator,
            .helper = helper,
            .nn = @as(i32, @intCast(nn)),
            .result_str = .{},
        };
        return self;
    }

    pub fn deinit(self: *Pidigits) void {
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Pidigits) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Pidigits");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Pidigits = @ptrCast(@alignCast(ptr));
        const n = self.nn;
        if (n <= 0) return;

        var ns: c.mpz_t = undefined;
        var a: c.mpz_t = undefined;
        var t: c.mpz_t = undefined;
        var u: c.mpz_t = undefined;
        var n_val: c.mpz_t = undefined;
        var d: c.mpz_t = undefined;
        var temp: c.mpz_t = undefined;
        var q: c.mpz_t = undefined;
        var dq: c.mpz_t = undefined;

        c.mpz_init(&ns);
        c.mpz_init(&a);
        c.mpz_init(&t);
        c.mpz_init(&u);
        c.mpz_init(&n_val);
        c.mpz_init(&d);
        c.mpz_init(&temp);
        c.mpz_init(&q);
        c.mpz_init(&dq);

        defer {
            c.mpz_clear(&ns);
            c.mpz_clear(&a);
            c.mpz_clear(&t);
            c.mpz_clear(&u);
            c.mpz_clear(&n_val);
            c.mpz_clear(&d);
            c.mpz_clear(&temp);
            c.mpz_clear(&q);
            c.mpz_clear(&dq);
        }

        c.mpz_set_ui(&ns, 0);
        c.mpz_set_ui(&a, 0);
        c.mpz_set_ui(&n_val, 1);
        c.mpz_set_ui(&d, 1);

        var i: i32 = 0;
        var k: i32 = 0;
        var k1: i32 = 1;

        var digit_buffer: [10]u8 = undefined;
        var buf_idx: usize = 0;

        while (true) {
            k += 1;

            c.mpz_mul_ui(&t, &n_val, 2);

            c.mpz_mul_ui(&n_val, &n_val, @as(c_ulong, @intCast(k)));

            k1 += 2;

            c.mpz_add(&a, &a, &t);
            c.mpz_mul_ui(&a, &a, @as(c_ulong, @intCast(k1)));

            c.mpz_mul_ui(&d, &d, @as(c_ulong, @intCast(k1)));

            if (c.mpz_cmp(&a, &n_val) >= 0) {

                c.mpz_mul_ui(&temp, &n_val, 3);
                c.mpz_add(&temp, &temp, &a);

                c.mpz_tdiv_q(&q, &temp, &d);

                c.mpz_tdiv_r(&u, &temp, &d);
                c.mpz_add(&u, &u, &n_val);

                if (c.mpz_cmp(&d, &u) > 0) {

                    c.mpz_mul_ui(&ns, &ns, 10);
                    c.mpz_add(&ns, &ns, &q);

                    i += 1;

                    const q_digit = @as(u8, @intCast(c.mpz_get_ui(&q)));
                    digit_buffer[buf_idx] = '0' + q_digit;
                    buf_idx += 1;

                    if (buf_idx == 10) {
                        self.result_str.appendSlice(self.allocator, digit_buffer[0..10]) catch return;
                        self.result_str.appendSlice(self.allocator, "\t:") catch return;

                        var num_buf: [10]u8 = undefined;
                        const num_str = std.fmt.bufPrint(&num_buf, "{}\n", .{i}) catch "0\n";
                        self.result_str.appendSlice(self.allocator, num_str) catch return;

                        buf_idx = 0;
                        c.mpz_set_ui(&ns, 0);
                    }

                    if (i >= n) break;

                    c.mpz_mul(&dq, &d, &q);
                    c.mpz_sub(&a, &a, &dq);
                    c.mpz_mul_ui(&a, &a, 10);

                    c.mpz_mul_ui(&n_val, &n_val, 10);
                }
            }
        }

        if (buf_idx > 0) {
            const ns_cstr = c.mpz_get_str(null, 10, &ns);
            defer std.c.free(ns_cstr);

            if (ns_cstr != null) {
                const ns_str = std.mem.span(ns_cstr);
                const copy_len = @min(ns_str.len, buf_idx);
                @memcpy(digit_buffer[0..copy_len], ns_str[0..copy_len]);
            }

            self.result_str.appendSlice(self.allocator, digit_buffer[0..buf_idx]) catch return;
            self.result_str.appendSlice(self.allocator, "\t:") catch return;
            var num_buf: [10]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{}\n", .{n}) catch "0\n";
            self.result_str.appendSlice(self.allocator, num_str) catch return;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Pidigits = @ptrCast(@alignCast(ptr));
        return self.helper.checksumString(self.result_str.items);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Pidigits = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};