const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const Knuckeotide = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    seq: std.ArrayListUnmanaged(u8),
    result_str: std.ArrayListUnmanaged(u8),
    n: i64,

    const KeyValue = struct { key: []const u8, value: usize };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Knuckeotide {
        const n = helper.config_i64("Knuckeotide", "n");

        const self = try allocator.create(Knuckeotide);
        errdefer allocator.destroy(self);

        self.* = Knuckeotide{
            .allocator = allocator,
            .helper = helper,
            .seq = .{},
            .result_str = .{},
            .n = n,
        };

        return self;
    }

    pub fn deinit(self: *Knuckeotide) void {
        self.seq.deinit(self.allocator);
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Knuckeotide) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Knuckeotide");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Knuckeotide = @ptrCast(@alignCast(ptr));

        self.seq.clearAndFree(self.allocator);

        var fasta = Fasta.init(self.allocator, self.helper) catch return;
        defer fasta.deinit();

        fasta.n = self.n;
        var benchmark = fasta.asBenchmark();
        benchmark.run(0);

        const fasta_result = fasta.getResult();

        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        var in_three_section = false;

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, ">THREE")) {
                in_three_section = true;
                continue;
            }

            if (in_three_section and line.len > 0 and line[0] != '>') {
                self.seq.appendSlice(self.allocator, line) catch return;
            }
        }
    }

    fn frequency(self: *Knuckeotide, length: usize) struct { n: usize, table: std.StringHashMap(usize) } {
        const seq_slice = self.seq.items;
        if (seq_slice.len < length) {
            return .{ .n = 0, .table = std.StringHashMap(usize).init(self.allocator) };
        }

        var table = std.StringHashMap(usize).init(self.allocator);
        const n = seq_slice.len - length + 1;

        for (0..n) |i| {
            const sub = seq_slice[i .. i + length];
            const entry = table.getOrPut(sub) catch continue;
            if (!entry.found_existing) {
                const key_copy = self.allocator.dupe(u8, sub) catch continue;
                entry.key_ptr.* = key_copy;
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
        }

        return .{ .n = n, .table = table };
    }

    fn sortByFreq(self: *Knuckeotide, length: usize) void {
        var freq_result = self.frequency(length);
        defer {
            var iter = freq_result.table.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            freq_result.table.deinit();
        }

        if (freq_result.n == 0) return;

        var pairs = std.ArrayListUnmanaged(KeyValue){};

        var iter = freq_result.table.iterator();
        while (iter.next()) |entry| {
            const key_copy = self.allocator.dupe(u8, entry.key_ptr.*) catch continue;
            pairs.append(self.allocator, .{ .key = key_copy, .value = entry.value_ptr.* }) catch {
                self.allocator.free(key_copy);
                continue;
            };
        }

        std.mem.sort(KeyValue, pairs.items, {}, struct {
            fn lessThan(context: void, a: KeyValue, b: KeyValue) bool {
                _ = context;
                if (a.value != b.value) return a.value > b.value;
                return std.mem.lessThan(u8, a.key, b.key);
            }
        }.lessThan);

        for (pairs.items) |pair| {
            const percent = (@as(f64, @floatFromInt(pair.value)) * 100.0) / @as(f64, @floatFromInt(freq_result.n));

            var upper_buf: [64]u8 = undefined;
            const copy_len = @min(pair.key.len, upper_buf.len);
            @memcpy(upper_buf[0..copy_len], pair.key[0..copy_len]);
            for (0..copy_len) |j| {
                upper_buf[j] = std.ascii.toUpper(upper_buf[j]);
            }
            const upper_key = upper_buf[0..copy_len];

            var buf: [128]u8 = undefined;
            const formatted = std.fmt.bufPrint(&buf, "{s} {d:.3}\n", .{ upper_key, percent }) catch continue;
            self.result_str.appendSlice(self.allocator, formatted) catch return;
        }

        self.result_str.appendSlice(self.allocator, "\n") catch return;

        for (pairs.items) |pair| {
            self.allocator.free(pair.key);
        }
        pairs.deinit(self.allocator);
    }

    fn findSeq(self: *Knuckeotide, search: []const u8) void {
        const length = search.len;
        var freq_result = self.frequency(length);
        defer {
            var iter = freq_result.table.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            freq_result.table.deinit();
        }

        var lower_buf: [64]u8 = undefined;
        const copy_len = @min(search.len, lower_buf.len);
        @memcpy(lower_buf[0..copy_len], search[0..copy_len]);
        for (0..copy_len) |i| {
            lower_buf[i] = std.ascii.toLower(lower_buf[i]);
        }
        const search_lower = lower_buf[0..copy_len];

        const count = freq_result.table.get(search_lower) orelse 0;

        var upper_buf: [64]u8 = undefined;
        @memcpy(upper_buf[0..copy_len], search[0..copy_len]);
        for (0..copy_len) |i| {
            upper_buf[i] = std.ascii.toUpper(upper_buf[i]);
        }
        const search_upper = upper_buf[0..copy_len];

        var buf: [128]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{}\t{s}\n", .{ count, search_upper }) catch return;
        self.result_str.appendSlice(self.allocator, formatted) catch return;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Knuckeotide = @ptrCast(@alignCast(ptr));

        for (1..3) |length| {
            self.sortByFreq(length);
        }

        const searches = [_][]const u8{ "ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt" };

        for (searches) |search| {
            self.findSeq(search);
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Knuckeotide = @ptrCast(@alignCast(ptr));
        return self.helper.checksumString(self.result_str.items);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Knuckeotide = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
