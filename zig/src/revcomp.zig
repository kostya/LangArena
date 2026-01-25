// src/revcomp.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const Revcomp = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    seq: std.ArrayListUnmanaged(u8), // Изменено с input на seq как в Knuckeotide
    result_str: std.ArrayListUnmanaged(u8),
    result_val: u64,
    n: i32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
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
        // Получаем n из конфигурации
        const n = helper.getInputInt("Revcomp");

        const self = try allocator.create(Revcomp);
        errdefer allocator.destroy(self);

        self.* = Revcomp{
            .allocator = allocator,
            .helper = helper,
            .seq = .{},
            .result_str = .{},
            .result_val = 0,
            .n = n,
        };

        return self;
    }

    pub fn deinit(self: *Revcomp) void {
        self.seq.deinit(self.allocator);
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Revcomp) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Функция обратной комплементарности
    fn revcomp(self: *Revcomp, seq: []const u8) ![]const u8 {
        // 1. Создаем реверсированную копию с заменой
        var reversed: std.ArrayList(u8) = .empty;
        defer reversed.deinit(self.allocator);
        reversed.ensureTotalCapacity(self.allocator, seq.len) catch return &[0]u8{};

        // Реверсируем и заменяем в одном проходе
        var i: usize = seq.len;
        while (i > 0) {
            i -= 1;
            const c = seq[i];
            const replaced = complement_table[@as(usize, @intCast(c))];
            reversed.appendAssumeCapacity(replaced);
        }

        // 2. Разбиваем на строки по 60 символов
        const LINE_LENGTH: usize = 60;
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(self.allocator);

        var pos: usize = 0;
        while (pos < reversed.items.len) {
            const end = @min(pos + LINE_LENGTH, reversed.items.len);
            result.appendSlice(self.allocator, reversed.items[pos..end]) catch return &[0]u8{};
            result.append(self.allocator, '\n') catch return &[0]u8{};
            pos += LINE_LENGTH;
        }

        // Возвращаем владение строкой
        const final_result = try self.allocator.dupe(u8, result.items);
        return final_result;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));

        // Очищаем последовательность
        self.seq.clearAndFree(self.allocator);

        // Копируем подход из Knuckeotide ОДИН В ОДИН
        var fasta = Fasta.init(self.allocator, self.helper) catch return;
        defer fasta.deinit();

        // ВОТ ТАК КАК В Knuckeotide!
        fasta.n = self.n;

        var benchmark = fasta.asBenchmark();
        benchmark.run();

        const fasta_result = fasta.getResult();

        // В Revcomp нужно всю FASTA последовательность
        // (не только THIRD секцию как в knuckeotide)
        var lines = std.mem.splitSequence(u8, fasta_result, "\n");

        while (lines.next()) |line| {
            if (line.len > 0) {
                self.seq.appendSlice(self.allocator, line) catch return;
                self.seq.append(self.allocator, '\n') catch return;
            }
        }
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));

        // Очищаем результат
        self.result_str.clearAndFree(self.allocator);

        // Парсим FASTA формат
        var lines = std.mem.splitSequence(u8, self.seq.items, "\n");
        var current_seq: std.ArrayList(u8) = .empty;
        defer current_seq.deinit(self.allocator);

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            if (line[0] == '>') {
                // Обрабатываем предыдущую последовательность
                if (current_seq.items.len > 0) {
                    const revcomp_result = self.revcomp(current_seq.items) catch return;
                    defer self.allocator.free(revcomp_result);
                    self.result_str.appendSlice(self.allocator, revcomp_result) catch return;
                    current_seq.clearAndFree(self.allocator);
                }

                // Добавляем заголовок
                self.result_str.appendSlice(self.allocator, line) catch return;
                self.result_str.append(self.allocator, '\n') catch return;
            } else {
                // Добавляем к текущей последовательности
                current_seq.appendSlice(self.allocator, line) catch return;
            }
        }

        // Обрабатываем последнюю последовательность
        if (current_seq.items.len > 0) {
            const revcomp_result = self.revcomp(current_seq.items) catch return;
            defer self.allocator.free(revcomp_result);
            self.result_str.appendSlice(self.allocator, revcomp_result) catch return;
        }

        // Вычисляем checksum
        self.result_val = self.helper.checksumString(self.result_str.items);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Revcomp = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
