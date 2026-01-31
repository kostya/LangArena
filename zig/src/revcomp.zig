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

    // Таблица замены для комплементарности (compile-time вычисление)
    const complement_table: [256]u8 = init: {
        @setEvalBranchQuota(10000);
        var table: [256]u8 = undefined;

        // Инициализируем таблицу значениями по умолчанию
        var i: u16 = 0;
        while (i < 256) : (i += 1) {
            table[i] = @as(u8, @intCast(i));
        }

        // Определяем пары замены
        const from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        const to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

        var j: usize = 0;
        while (j < from.len) : (j += 1) {
            const from_char = from[j];
            const to_char = to[j];
            table[@as(usize, @intCast(from_char))] = to_char;
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

    // Функция обратной комплементарности - точная копия C++ версии
    fn revcomp(seq: []const u8, allocator: std.mem.Allocator) ![]u8 {
        // 1. Реверсируем последовательность
        var reversed = std.ArrayList(u8){};
        defer reversed.deinit(allocator);

        try reversed.ensureTotalCapacity(allocator, seq.len);
        
        var i: usize = seq.len;
        while (i > 0) : (i -= 1) {
            const c = seq[i - 1];
            const replaced = complement_table[@as(usize, @intCast(c))];
            try reversed.append(allocator, replaced);
        }

        // 2. Разбиваем на строки по 60 символов с \n
        const LINE_LENGTH: usize = 60;
        var result = std.ArrayList(u8){};
        defer result.deinit(allocator);

        var pos: usize = 0;
        const rev_items = reversed.items;
        while (pos < rev_items.len) {
            const end = @min(pos + LINE_LENGTH, rev_items.len);
            try result.appendSlice(allocator, rev_items[pos..end]);
            try result.append(allocator, '\n');
            pos += LINE_LENGTH;
        }

        return result.toOwnedSlice(allocator);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем данные
        self.input.clearAndFree(allocator);

        // Получаем FASTA данные как в C++ версии
        var fasta = Fasta.init(allocator, self.helper) catch return;
        defer fasta.deinit();

        fasta.n = self.n;
        var benchmark = fasta.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        const fasta_result = fasta.getResult();

        // Парсим ТОЧНО как в C++ версии
        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        
        while (lines.next()) |line| {
            if (line.len > 0) {
                if (line[0] == '>') {
                    // Заголовок - добавляем разделитель (даже для первого!)
                    self.input.appendSlice(allocator, "\n---\n") catch return;
                } else {
                    // Последовательность - добавляем как есть
                    self.input.appendSlice(allocator, line) catch return;
                }
            }
        }
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Вычисляем revcomp для всего input (включая разделители!)
        const revcomp_result = revcomp(self.input.items, allocator) catch return;
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