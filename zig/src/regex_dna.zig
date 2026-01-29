const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const Fasta = @import("fasta.zig").Fasta;

pub const RegexDna = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    seq: std.ArrayList(u8),
    result_val: u32, // Изменено с u64 на u32 как в C++: uint32_t checksum_val
    n: i32,
    ilen: i32,
    clen: i32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*RegexDna {
        const n = helper.getInputInt("RegexDna");

        const self = try allocator.create(RegexDna);
        errdefer allocator.destroy(self);

        self.* = RegexDna{
            .allocator = allocator,
            .helper = helper,
            .seq = .empty,
            .result_val = 0,
            .n = n,
            .ilen = 0,
            .clen = 0,
        };

        return self;
    }

    pub fn deinit(self: *RegexDna) void {
        const allocator = self.allocator;
        self.seq.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *RegexDna) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Метод config_val как в C++
    fn config_val(self: *RegexDna, field_name: []const u8) i64 {
        return self.helper.config_i64("RegexDna", field_name);
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
        fasta_bench.prepare();
        fasta_bench.run(0); // Запускаем одну итерацию как в C++

        const fasta_result = fasta.getResult();

        // Копируем подход из C++: each_line удаляет \n, потом добавляет +1
        var lines = std.mem.splitSequence(u8, fasta_result, "\n");
        self.ilen = 0;

        while (lines.next()) |line| {
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
    }

    // Простая функция подсчета вхождений (как в C++ версии)
    fn countPattern(self: *RegexDna, pattern: []const u8) usize {
        var count: usize = 0;
        var pos: usize = 0;
        const seq = self.seq.items;

        while (pos < seq.len) {
            if (std.mem.startsWith(u8, seq[pos..], pattern)) {
                count += 1;
                pos += pattern.len;
            } else {
                pos += 1;
            }
        }

        return count;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        _ = iteration_id; // Не используется

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

        // Подсчет паттернов
        for (PATTERNS) |pattern| {
            const count = self.countPattern(pattern);
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

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *RegexDna = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};