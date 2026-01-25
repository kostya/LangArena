// src/regex_dna.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const RegexDna = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    seq: std.ArrayList(u8),
    result_val: u64,
    n: i32,
    ilen: i32,
    clen: i32,

    // PCRE2 структуры
    compiled_patterns: [9]?*anyopaque, // pcre2_code_8*
    match_data: [9]?*anyopaque, // pcre2_match_data_8*

    const PATTERNS = [_][]const u8{
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct",
    };

    const REPLACEMENTS = [_]struct { from: u8, to: []const u8, len: usize }{
        .{ .from = 'B', .to = "(c|g|t)", .len = 7 },
        .{ .from = 'D', .to = "(a|g|t)", .len = 7 },
        .{ .from = 'H', .to = "(a|c|t)", .len = 7 },
        .{ .from = 'K', .to = "(g|t)", .len = 5 },
        .{ .from = 'M', .to = "(a|c)", .len = 5 },
        .{ .from = 'N', .to = "(a|c|g|t)", .len = 9 },
        .{ .from = 'R', .to = "(a|g)", .len = 5 },
        .{ .from = 'S', .to = "(c|t)", .len = 5 },
        .{ .from = 'V', .to = "(a|c|g)", .len = 7 },
        .{ .from = 'W', .to = "(a|t)", .len = 5 },
        .{ .from = 'Y', .to = "(c|t)", .len = 5 },
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*RegexDna {
        const n = helper.getInputInt("RegexDna");

        const self = try allocator.create(RegexDna);
        errdefer allocator.destroy(self);

        // Инициализируем массивы как null
        var compiled_patterns: [9]?*anyopaque = undefined;
        var match_data: [9]?*anyopaque = undefined;
        @memset(&compiled_patterns, null);
        @memset(&match_data, null);

        self.* = RegexDna{
            .allocator = allocator,
            .helper = helper,
            .seq = .empty,
            .result_val = 0,
            .n = n,
            .ilen = 0,
            .clen = 0,
            .compiled_patterns = compiled_patterns,
            .match_data = match_data,
        };

        return self;
    }

    pub fn deinit(self: *RegexDna) void {
        const allocator = self.allocator;

        // Освобождаем PCRE2 ресурсы
        for (0..9) |i| {
            if (self.match_data[i]) |md| {
                pcre2_match_data_free_8(@ptrCast(md));
            }
            if (self.compiled_patterns[i]) |cp| {
                pcre2_code_free_8(@ptrCast(cp));
            }
        }

        self.seq.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *RegexDna) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем предыдущие данные
        self.seq.clearRetainingCapacity();

        // Создаем Fasta
        var fasta = Fasta.init(allocator, self.helper) catch return;
        defer fasta.deinit();

        fasta.n = self.n;
        var fasta_bench = fasta.asBenchmark();
        fasta_bench.run();

        const fasta_result = fasta.getResult();

        // Проверим Crystal логику: each_line удаляет \n, потом добавляет +1
        // Если последний символ \n, то last line будет пустой строкой
        // Crystal each_line пропускает пустые строки в конце

        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        self.ilen = 0;

        while (lines.next()) |line| {
            // Crystal each_line возвращает строки без \n
            // Если это последняя строка и она пустая (из-за trailing \n), пропускаем
            if (line.len == 0 and lines.peek() == null) {
                break;
            }

            self.ilen += @as(i32, @intCast(line.len)) + 1;

            if (line.len > 0 and line[0] != '>') {
                self.seq.appendSlice(allocator, line) catch return;
            }
        }

        self.clen = @as(i32, @intCast(self.seq.items.len));

        // std.debug.print("Final ilen: {d}, clen: {d}\n", .{ self.ilen, self.clen });
        // ============ КОМПИЛИРУЕМ PCRE2 С JIT ============
        for (PATTERNS, 0..) |pattern, i| {
            // Освобождаем предыдущие ресурсы
            if (self.match_data[i]) |md| {
                pcre2_match_data_free_8(@ptrCast(md));
                self.match_data[i] = null;
            }
            if (self.compiled_patterns[i]) |cp| {
                pcre2_code_free_8(@ptrCast(cp));
                self.compiled_patterns[i] = null;
            }

            var error_number: c_int = 0;
            var error_offset: usize = 0;

            // Компилируем паттерн
            const re = pcre2_compile_8(
                @ptrCast(pattern.ptr),
                pattern.len,
                pcre2_utf | pcre2_no_utf_check,
                &error_number,
                &error_offset,
                null,
            );

            if (re == null) {
                std.debug.print("PCRE2 compilation failed for pattern {}: {s}\n", .{ i, pattern });
                continue;
            }

            // JIT компиляция для максимальной производительности
            _ = pcre2_jit_compile_8(@ptrCast(re), pcre2_jit_complete);

            // Создаем match data
            const md = pcre2_match_data_create_from_pattern_8(@ptrCast(re), null);
            if (md == null) {
                pcre2_code_free_8(@ptrCast(re));
                continue;
            }

            self.compiled_patterns[i] = @ptrCast(re);
            self.match_data[i] = @ptrCast(md);
        }
    }

    // Подсчет вхождений с PCRE2 JIT (оптимизировано)
    fn countPatternOptimized(self: *RegexDna, pattern_idx: usize) usize {
        const re_ptr = self.compiled_patterns[pattern_idx] orelse return 0;
        const md_ptr = self.match_data[pattern_idx] orelse return 0;

        const re: *pcre2_code_8 = @ptrCast(re_ptr);
        const md: *pcre2_match_data_8 = @ptrCast(md_ptr);

        var count: usize = 0;
        var start_offset: usize = 0;
        const subject = self.seq.items.ptr;
        const subject_length = self.seq.items.len;

        while (true) {
            // Используем JIT match для максимальной производительности!
            const rc = pcre2_jit_match_8(
                re,
                @ptrCast(subject),
                subject_length,
                start_offset,
                0,
                md,
                null,
            );

            if (rc < 0) {
                if (rc == pcre2_error_nomatch) break;
                break;
            }

            count += 1;

            const ovector = pcre2_get_ovector_pointer_8(md);
            start_offset = ovector[1];

            // Если совпадение нулевой длины, двигаемся на 1 символ
            if (ovector[0] == ovector[1]) {
                start_offset += 1;
            }

            if (start_offset > subject_length) break;
        }

        return count;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const seq = self.seq.items;

        // Используем arena для временных аллокаций
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Создаем буфер для результата
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(arena_allocator);

        const writer = result.writer(arena_allocator);

        // Подсчет паттернов с PCRE2 JIT
        for (PATTERNS, 0..) |pattern, i| {
            const count = self.countPatternOptimized(i);
            _ = writer.print("{s} {d}\n", .{ pattern, count }) catch return;
        }

        // Оптимизированная замена через lookup table (как в C коде)
        var seq2: std.ArrayList(u8) = .empty;
        defer seq2.deinit(arena_allocator);

        // Предварительно выделяем память (максимальный возможный размер)
        const max_seq2_len = seq.len * 9;
        seq2.ensureTotalCapacity(arena_allocator, max_seq2_len) catch return;

        for (seq) |ch| {
            var replaced = false;
            inline for (REPLACEMENTS) |repl| {
                if (ch == repl.from) {
                    seq2.appendSliceAssumeCapacity(repl.to);
                    replaced = true;
                    break;
                }
            }
            if (!replaced) {
                seq2.appendAssumeCapacity(ch);
            }
        }

        // Добавляем статистику
        _ = writer.print("\n{d}\n{d}\n{d}\n", .{
            self.ilen,
            self.clen,
            seq2.items.len,
        }) catch return;

        // Вычисляем checksum
        self.result_val = self.helper.checksumString(result.items);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// ============ PCRE2 C API Объявления (8-битная версия) ============
// Определяем константы как в C коде
const pcre2_utf = 0x00080000;
const pcre2_no_utf_check = 0x40000000;
const pcre2_jit_complete = 0x00000001;
const pcre2_error_nomatch = -1;

// PCRE2 типы
const pcre2_code_8 = opaque {};
const pcre2_match_data_8 = opaque {};

// PCRE2 функции
extern fn pcre2_compile_8(
    pattern: [*c]const u8,
    length: usize,
    options: u32,
    errorcode: [*c]c_int,
    erroroffset: [*c]usize,
    ccontext: ?*anyopaque,
) ?*pcre2_code_8;

extern fn pcre2_code_free_8(code: ?*pcre2_code_8) void;

extern fn pcre2_jit_compile_8(
    code: ?*pcre2_code_8,
    options: u32,
) c_int;

extern fn pcre2_match_data_create_from_pattern_8(
    code: ?*const pcre2_code_8,
    gcontext: ?*anyopaque,
) ?*pcre2_match_data_8;

extern fn pcre2_match_data_free_8(match_data: ?*pcre2_match_data_8) void;

extern fn pcre2_jit_match_8(
    code: *const pcre2_code_8,
    subject: [*c]const u8,
    length: usize,
    startoffset: usize,
    options: u32,
    match_data: ?*pcre2_match_data_8,
    mcontext: ?*anyopaque,
) c_int;

extern fn pcre2_get_ovector_pointer_8(
    match_data: ?*pcre2_match_data_8,
) [*c]usize;
