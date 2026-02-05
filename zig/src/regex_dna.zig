const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const RegexDna = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    seq: std.ArrayList(u8),
    result_str: std.ArrayList(u8),
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

    const REPLACEMENTS = [_]struct { from: u8, to: []const u8 }{
        .{ .from = 'B', .to = "(c|g|t)" },
        .{ .from = 'D', .to = "(a|g|t)" },
        .{ .from = 'H', .to = "(a|c|t)" },
        .{ .from = 'K', .to = "(g|t)" },
        .{ .from = 'M', .to = "(a|c)" },
        .{ .from = 'N', .to = "(a|c|g|t)" },
        .{ .from = 'R', .to = "(a|g)" },
        .{ .from = 'S', .to = "(c|t)" },
        .{ .from = 'V', .to = "(a|c|g)" },
        .{ .from = 'W', .to = "(a|t)" },
        .{ .from = 'Y', .to = "(c|t)" },
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*RegexDna {
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
            .seq = .{},
            .result_str = .{},
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
        self.result_str.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *RegexDna) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "RegexDna");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем предыдущие данные
        self.seq.clearAndFree(allocator);
        self.result_str.clearAndFree(allocator);

        // Создаем Fasta как в C++ версии
        var fasta = Fasta.init(allocator, self.helper) catch return;
        defer fasta.deinit();

        // Устанавливаем n из конфига
        const n_val = self.helper.config_i64("RegexDna", "n");
        fasta.n = n_val;

        // Получаем benchmark и запускаем prepare + run
        var fasta_bench = fasta.asBenchmark();
        fasta_bench.prepare();
        fasta_bench.run(0); // Запускаем одну итерацию

        const fasta_result = fasta.getResult();

        // Парсим результат Fasta как в C++ версии
        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        self.ilen = 0;
        self.seq.clearRetainingCapacity();

        while (lines.next()) |line| {
            // Пропускаем пустую строку в конце
            if (line.len == 0 and lines.peek() == null) {
                break;
            }

            self.ilen += @as(i32, @intCast(line.len)) + 1;

            if (line.len > 0 and line[0] != '>') {
                self.seq.appendSlice(allocator, line) catch return;
            }
        }

        self.clen = @as(i32, @intCast(self.seq.items.len));

        // Компилируем PCRE2 паттерны
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
                PCRE2_UTF | PCRE2_NO_UTF_CHECK,
                &error_number,
                &error_offset,
                null,
            );

            if (re == null) {
                continue;
            }

            // JIT компиляция
            _ = pcre2_jit_compile_8(@ptrCast(re), PCRE2_JIT_COMPLETE);

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

    // Подсчет вхождений с PCRE2
    fn countPattern(self: *RegexDna, pattern_idx: usize) usize {
        const re_ptr = self.compiled_patterns[pattern_idx] orelse return 0;
        const md_ptr = self.match_data[pattern_idx] orelse return 0;

        const re: *PCRE2_CODE = @ptrCast(re_ptr);
        const md: *PCRE2_MATCH_DATA = @ptrCast(md_ptr);

        var count: usize = 0;
        var start_offset: usize = 0;
        const subject = self.seq.items.ptr;
        const subject_length = self.seq.items.len;

        while (true) {
            const rc = pcre2_match_8(
                re,
                @ptrCast(subject),
                subject_length,
                start_offset,
                0,
                md,
                null,
            );

            if (rc < 0) {
                if (rc == PCRE2_ERROR_NOMATCH) break;
                break;
            }

            count += 1;

            const ovector = pcre2_get_ovector_pointer_8(md);
            start_offset = ovector[1];

            if (ovector[0] == ovector[1]) {
                start_offset += 1;
            }

            if (start_offset > subject_length) break;
        }

        return count;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Подсчет паттернов с PCRE2
        for (PATTERNS, 0..) |pattern, i| {
            const count = self.countPattern(i);

            // Формируем строку
            var buf: [128]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "{s} {d}\n", .{pattern, count}) catch continue;
            self.result_str.appendSlice(allocator, line) catch continue;
        }

        // Замена символов
        const seq = self.seq.items;
        var seq2 = std.ArrayList(u8){};

        // Используем arena для seq2
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        seq2.ensureTotalCapacity(arena_allocator, seq.len * 9) catch return;
        defer seq2.deinit(arena_allocator);

        for (seq) |ch| {
            var replaced = false;
            for (REPLACEMENTS) |repl| {
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
        var buf2: [64]u8 = undefined;
        const stats = std.fmt.bufPrint(&buf2, "\n{d}\n{d}\n{d}\n", .{
            self.ilen,
            self.clen,
            seq2.items.len,
        }) catch return;

        self.result_str.appendSlice(allocator, stats) catch return;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        return self.helper.checksumString(self.result_str.items);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// ============ PCRE2 Константы ============
const PCRE2_UTF = 0x00080000;
const PCRE2_NO_UTF_CHECK = 0x40000000;
const PCRE2_JIT_COMPLETE = 0x00000001;
const PCRE2_ERROR_NOMATCH = -1;

// ============ PCRE2 Типы ============
const PCRE2_CODE = opaque {};
const PCRE2_MATCH_DATA = opaque {};

// ============ PCRE2 Функции ============
extern "c" fn pcre2_compile_8(
    pattern: [*c]const u8,
    length: usize,
    options: u32,
    errorcode: [*c]c_int,
    erroroffset: [*c]usize,
    ccontext: ?*anyopaque,
) ?*PCRE2_CODE;

extern "c" fn pcre2_code_free_8(code: ?*PCRE2_CODE) void;

extern "c" fn pcre2_jit_compile_8(
    code: ?*PCRE2_CODE,
    options: u32,
) c_int;

extern "c" fn pcre2_match_data_create_from_pattern_8(
    code: ?*const PCRE2_CODE,
    gcontext: ?*anyopaque,
) ?*PCRE2_MATCH_DATA;

extern "c" fn pcre2_match_data_free_8(match_data: ?*PCRE2_MATCH_DATA) void;

extern "c" fn pcre2_match_8(
    code: *const PCRE2_CODE,
    subject: [*c]const u8,
    length: usize,
    startoffset: usize,
    options: u32,
    match_data: ?*PCRE2_MATCH_DATA,
    mcontext: ?*anyopaque,
) c_int;

extern "c" fn pcre2_get_ovector_pointer_8(
    match_data: ?*PCRE2_MATCH_DATA,
) [*c]usize;

// JIT match функция (если доступна)
extern "c" fn pcre2_jit_match_8(
    code: *const PCRE2_CODE,
    subject: [*c]const u8,
    length: usize,
    startoffset: usize,
    options: u32,
    match_data: ?*PCRE2_MATCH_DATA,
    mcontext: ?*anyopaque,
) c_int;