const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Fasta = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_str: std.ArrayListUnmanaged(u8),
    result_val: u32,

    const Gene = struct {
        c: u8,
        prob: f64,
    };

    const LINE_LENGTH: usize = 60;
    const IUB = [_]Gene{
        .{ .c = 'a', .prob = 0.27 },
        .{ .c = 'c', .prob = 0.39 },
        .{ .c = 'g', .prob = 0.51 },
        .{ .c = 't', .prob = 0.78 },
        .{ .c = 'B', .prob = 0.8 },
        .{ .c = 'D', .prob = 0.8200000000000001 },
        .{ .c = 'H', .prob = 0.8400000000000001 },
        .{ .c = 'K', .prob = 0.8600000000000001 },
        .{ .c = 'M', .prob = 0.8800000000000001 },
        .{ .c = 'N', .prob = 0.9000000000000001 },
        .{ .c = 'R', .prob = 0.9200000000000002 },
        .{ .c = 'S', .prob = 0.9400000000000002 },
        .{ .c = 'V', .prob = 0.9600000000000002 },
        .{ .c = 'W', .prob = 0.9800000000000002 },
        .{ .c = 'Y', .prob = 1.0000000000000002 },
    };

    const HOMO = [_]Gene{
        .{ .c = 'a', .prob = 0.302954942668 },
        .{ .c = 'c', .prob = 0.5009432431601 },
        .{ .c = 'g', .prob = 0.6984905497992 },
        .{ .c = 't', .prob = 1.0 },
    };

    const ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Fasta {
        const n = helper.config_i64("Fasta", "n");

        const self = try allocator.create(Fasta);
        errdefer allocator.destroy(self);

        self.* = Fasta{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_str = .{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Fasta) void {
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Fasta) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Fasta");
    }

    pub fn getResult(self: *const Fasta) []const u8 {
        return self.result_str.items;
    }

    fn selectRandom(self: *Fasta, genelist: []const Gene) u8 {
        const r = self.helper.nextFloat(1.0);

        if (r < genelist[0].prob) return genelist[0].c;

        var lo: usize = 0;
        var hi: usize = genelist.len - 1;

        while (hi > lo + 1) {
            const i = (hi + lo) / 2;
            if (r < genelist[i].prob) {
                hi = i;
            } else {
                lo = i;
            }
        }

        return genelist[hi].c;
    }

    fn makeRandomFasta(self: *Fasta, id: []const u8, desc: []const u8, genelist: []const Gene, n_iter: i32) void {
        self.result_str.appendSlice(self.allocator, ">") catch return;
        self.result_str.appendSlice(self.allocator, id) catch return;
        self.result_str.appendSlice(self.allocator, " ") catch return;
        self.result_str.appendSlice(self.allocator, desc) catch return;
        self.result_str.appendSlice(self.allocator, "\n") catch return;

        var todo: i32 = n_iter;

        while (todo > 0) {
            const m_val = if (todo < LINE_LENGTH) todo else @as(i32, @intCast(LINE_LENGTH));
            const m = @as(usize, @intCast(m_val));

            var buffer: [LINE_LENGTH]u8 = undefined;

            for (0..m) |i| {
                buffer[i] = self.selectRandom(genelist);
            }

            self.result_str.appendSlice(self.allocator, buffer[0..m]) catch return;
            self.result_str.appendSlice(self.allocator, "\n") catch return;

            todo -= @as(i32, @intCast(LINE_LENGTH));
        }
    }

    fn makeRepeatFasta(self: *Fasta, id: []const u8, desc: []const u8, s: []const u8, n_iter: i32) void {
        self.result_str.appendSlice(self.allocator, ">") catch return;
        self.result_str.appendSlice(self.allocator, id) catch return;
        self.result_str.appendSlice(self.allocator, " ") catch return;
        self.result_str.appendSlice(self.allocator, desc) catch return;
        self.result_str.appendSlice(self.allocator, "\n") catch return;

        var todo: i32 = n_iter;
        var k: usize = 0;
        const kn = s.len;

        while (todo > 0) {
            const m_val = if (todo < LINE_LENGTH) todo else @as(i32, @intCast(LINE_LENGTH));
            var m = @as(usize, @intCast(m_val));

            while (m >= kn - k) {
                self.result_str.appendSlice(self.allocator, s[k..]) catch return;
                m -= (kn - k);
                k = 0;
            }

            self.result_str.appendSlice(self.allocator, s[k .. k + m]) catch return;
            self.result_str.appendSlice(self.allocator, "\n") catch return;

            k += m;
            todo -= @as(i32, @intCast(LINE_LENGTH));
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Fasta = @ptrCast(@alignCast(ptr));

        const n = @as(i32, @intCast(self.n));
        self.makeRepeatFasta("ONE", "Homo sapiens alu", ALU, n * 2);
        self.makeRandomFasta("TWO", "IUB ambiguity codes", &IUB, n * 3);
        self.makeRandomFasta("THREE", "Homo sapiens frequency", &HOMO, n * 5);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Fasta = @ptrCast(@alignCast(ptr));
        return self.helper.checksumString(self.result_str.items);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Fasta = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
