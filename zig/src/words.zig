const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Words = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    words: usize,
    word_len: usize,
    text: []u8,
    checksum_val: u32,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Words {
        const words = @as(usize, @intCast(helper.config_i64("Etc::Words", "words")));
        const word_len = @as(usize, @intCast(helper.config_i64("Etc::Words", "word_len")));

        const self = try allocator.create(Words);
        errdefer allocator.destroy(self);

        self.* = Words{
            .allocator = allocator,
            .helper = helper,
            .words = words,
            .word_len = word_len,
            .text = &[0]u8{},
            .checksum_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *Words) void {
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Words) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Etc::Words");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Words = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (self.text.len > 0) {
            allocator.free(self.text);
        }

        const chars = "abcdefghijklmnopqrstuvwxyz";
        const char_count = chars.len;

        var text_buf: std.ArrayList(u8) = .empty;
        defer text_buf.deinit(allocator);

        for (0..self.words) |i| {
            const word_len = @as(usize, @intCast(self.helper.next_int(@intCast(self.word_len)) +
                self.helper.next_int(3) + 3));

            for (0..word_len) |_| {
                const idx = self.helper.next_int(@intCast(char_count));
                text_buf.append(allocator, chars[@as(usize, @intCast(idx))]) catch return;
            }
            if (i < self.words - 1) {
                text_buf.append(allocator, ' ') catch return;
            }
        }

        self.text = text_buf.toOwnedSlice(allocator) catch return;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Words = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const arena_allocator = arena.allocator();

        var frequencies = std.StringHashMap(u32).init(arena_allocator);
        defer frequencies.deinit();

        var it = std.mem.splitScalar(u8, self.text, ' ');
        while (it.next()) |word| {
            if (word.len == 0) continue;
            const entry = frequencies.getOrPut(word) catch return;
            if (entry.found_existing) {
                entry.value_ptr.* += 1;
            } else {
                entry.value_ptr.* = 1;
            }
        }

        var max_word: []const u8 = "";
        var max_count: u32 = 0;

        var iter = frequencies.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* > max_count) {
                max_count = entry.value_ptr.*;
                max_word = entry.key_ptr.*;
            }
        }

        const freq_size = @as(u32, @intCast(frequencies.count()));
        const word_checksum = self.helper.checksum(max_word);

        self.checksum_val +%= max_count +% word_checksum +% freq_size;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Words = @ptrCast(@alignCast(ptr));
        return self.checksum_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Words = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
