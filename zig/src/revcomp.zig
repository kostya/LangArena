const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const Revcomp = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    input: std.ArrayList(u8),
    n: i32,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    const complement_table: [256]u8 = init: {
        @setEvalBranchQuota(10000);
        var table: [256]u8 = undefined;

        for (&table, 0..) |*item, i| {
            item.* = @as(u8, @intCast(i));
        }

        const from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        const to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

        for (from, 0..) |from_char, i| {
            table[@as(usize, @intCast(from_char))] = to[i];
        }

        break :init table;
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Revcomp {
        const n = @as(i32, @intCast(helper.config_i64("Revcomp", "n")));

        const self = try allocator.create(Revcomp);
        errdefer allocator.destroy(self);

        self.* = Revcomp{
            .allocator = allocator,
            .helper = helper,
            .input = .{},
            .n = n,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Revcomp) void {
        const allocator = self.allocator;
        self.input.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Revcomp) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Revcomp");
    }

    fn revcompFast(seq: []const u8, allocator: std.mem.Allocator) ![]u8 {
        const len = seq.len;
        const lines = (len + 59) / 60;
        const total_size = len + lines;

        var result = try allocator.alloc(u8, total_size);
        var pos: usize = 0;

        var start = len;
        while (start > 0) {
            const chunk_start = if (start >= 60) start - 60 else 0;

            var i: usize = start;
            while (i > chunk_start) {
                i -= 1;
                const c = seq[i];
                result[pos] = complement_table[@as(usize, @intCast(c))];
                pos += 1;
            }

            result[pos] = '\n';
            pos += 1;
            start = chunk_start;
        }

        if (len % 60 == 0 and len > 0) {
            pos -= 1;
        }

        return result[0..pos];
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        self.input.clearAndFree(allocator);

        var fasta = Fasta.init(allocator, self.helper) catch return;
        defer fasta.deinit();

        fasta.n = self.n;
        var benchmark = fasta.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        const fasta_result = fasta.getResult();

        var i: usize = 0;
        while (i < fasta_result.len) {

            var line_end = i;
            while (line_end < fasta_result.len and fasta_result[line_end] != '\n') {
                line_end += 1;
            }

            const line = fasta_result[i..line_end];

            if (line.len > 0) {
                if (line[0] == '>') {
                    self.input.appendSlice(allocator, "\n---\n") catch return;
                } else {
                    self.input.appendSlice(allocator, line) catch return;
                }
            }

            i = line_end + 1; 
        }
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        const revcomp_result = revcompFast(self.input.items, allocator) catch return;
        defer allocator.free(revcomp_result);

        self.result_val +%= self.helper.checksumBytes(revcomp_result);
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};