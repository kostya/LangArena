const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const Revcomp = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    input: std.ArrayListUnmanaged(u8),
    result_val: u32, // Изменено с u64 на u32
    n: i32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
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
        const n = helper.getInputInt("Revcomp");

        const self = try allocator.create(Revcomp);
        errdefer allocator.destroy(self);

        self.* = Revcomp{
            .allocator = allocator,
            .helper = helper,
            .input = .{},
            .result_val = 0,
            .n = n,
        };

        return self;
    }

    pub fn deinit(self: *Revcomp) void {
        self.input.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Revcomp) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Метод config_val как в C++
    fn config_val(self: *Revcomp, field_name: []const u8) i64 {
        return self.helper.config_i64("Revcomp", field_name);
    }

    // Функция обратной комплементарности
    fn revcomp(self: *Revcomp, seq: []const u8) ![]u8 {
        // Создаем реверсированную копию с заменой
        var reversed = std.ArrayList(u8).init(self.allocator);
        defer reversed.deinit();

        try reversed.ensureTotalCapacity(seq.len);

        // Реверсируем и заменяем в одном проходе
        var i: usize = seq.len;
        while (i > 0) {
            i -= 1;
            const c = seq[i];
            const replaced = complement_table[@as(usize, @intCast(c))];
            reversed.appendAssumeCapacity(replaced);
        }

        // Разбиваем на строки по 60 символов
        const LINE_LENGTH: usize = 60;
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        var pos: usize = 0;
        while (pos < reversed.items.len) {
            const end = @min(pos + LINE_LENGTH, reversed.items.len);
            try result.appendSlice(reversed.items[pos..end]);
            try result.append('\n');
            pos += LINE_LENGTH;
        }

        return result.toOwnedSlice();
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));

        // Очищаем последовательность
        self.input.clearAndFree(self.allocator);

        // Копируем подход из C++: берем всю FASTA последовательность
        var fasta = Fasta.init(self.allocator, self.helper) catch return;
        defer fasta.deinit();

        fasta.n = self.n;
        var benchmark = fasta.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        const fasta_result = fasta.getResult();

        // В Revcomp нужно всю FASTA последовательность
        // В C++ версии: берем всю последовательность с разделителем "---"
        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        var first_line = true;

        while (lines.next()) |line| {
            if (line.len > 0) {
                if (!first_line) {
                    self.input.append(self.allocator, '\n') catch return;
                }
                self.input.appendSlice(self.allocator, line) catch return;
                first_line = false;
            }
        }

        // Добавляем разделитель как в C++ версии
        self.input.appendSlice(self.allocator, "\n---\n") catch return;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        // Просто вычисляем revcomp для input как в C++ версии
        const revcomp_result = self.revcomp(self.input.items) catch return;
        defer self.allocator.free(revcomp_result);

        // Вычисляем checksum
        self.result_val = self.helper.checksumString(revcomp_result);
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