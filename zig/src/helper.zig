// src/helper.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Helper = struct {
    const IM: i32 = 139968;
    const IA: i32 = 3877;
    const IC: i32 = 29573;
    const INIT: i32 = 42;

    const ConfigValue = struct {
        arg: []const u8,
        expected: i64,
    };

    last: i32,
    config: std.StringHashMap(ConfigValue),

    pub fn init(allocator: Allocator) !Helper {
        return Helper{
            .last = INIT,
            .config = std.StringHashMap(ConfigValue).init(allocator),
        };
    }

    pub fn deinit(self: *Helper) void {
        var iter = self.config.iterator();
        while (iter.next()) |entry| {
            self.config.allocator.free(entry.key_ptr.*);
            self.config.allocator.free(entry.value_ptr.arg);
        }
        self.config.deinit();
    }

    pub fn reset(self: *Helper) void {
        self.last = INIT;
    }

    // Функция для получения положительного остатка как в C++/C#/Rust
    fn positiveMod(a: i32, b: i32) i32 {
        const rem = @rem(a, b);
        return if (rem < 0) rem + b else rem;
    }

    pub fn nextInt(self: *Helper, max: i32) i32 {
        // Используем wrapping операции как в C++ для эмуляции 32-bit переполнения
        self.last = positiveMod(self.last *% IA +% IC, IM);
        // Формула как в C++/Rust: (last * max / IM) с использованием float
        return @intFromFloat(@as(f64, @floatFromInt(self.last)) * @as(f64, @floatFromInt(max)) / @as(f64, @floatFromInt(IM)));
    }

    pub fn nextIntRange(self: *Helper, from: i32, to: i32) i32 {
        return self.nextInt(to - from + 1) + from;
    }

    pub fn nextFloat(self: *Helper, max: f64) f64 {
        // Точная формула как в C++/C#/Rust
        self.last = positiveMod(self.last *% IA +% IC, IM);
        return max * @as(f64, @floatFromInt(self.last)) / @as(f64, @floatFromInt(IM));
    }

    // Хеш-функция (аналогичная Crystal/C++ версии)
    pub fn checksumString(_: *Helper, v: []const u8) u32 {
        var hash: u32 = 5381;
        for (v) |byte| {
            hash = ((hash << 5) +% hash) +% byte;
        }
        return hash;
    }

    pub fn checksumBytes(_: *Helper, v: []const u8) u32 {
        var hash: u32 = 5381;
        for (v) |byte| {
            hash = ((hash << 5) +% hash) +% byte;
        }
        return hash;
    }

    pub fn checksumFloat(self: *Helper, v: f64) u32 {
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.7}", .{v}) catch "0.0000000";
        return self.checksumString(formatted);
    }

    pub fn loadConfig(self: *Helper, allocator: Allocator, filename: ?[]const u8) !void {
        const default_filename = "test.txt";
        const actual_filename = filename orelse default_filename;

        const file = try std.fs.cwd().openFile(actual_filename, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var parts = std.mem.splitScalar(u8, line, '|');

            const bench = parts.next() orelse continue;
            const arg = parts.next() orelse continue;
            const expected_str = parts.next() orelse continue;

            const expected = std.fmt.parseInt(i64, expected_str, 10) catch continue;

            // Копируем строки с помощью аллокатора хэш-мапы
            const bench_copy = try self.config.allocator.dupe(u8, bench);
            const arg_copy = try self.config.allocator.dupe(u8, arg);

            try self.config.put(bench_copy, .{ .arg = arg_copy, .expected = expected });
        }
    }

    pub fn getInput(self: *Helper, bench_name: []const u8) ?[]const u8 {
        if (self.config.get(bench_name)) |config| {
            return config.arg;
        }
        return null;
    }

    pub fn getExpect(self: *Helper, bench_name: []const u8) ?i64 {
        if (self.config.get(bench_name)) |config| {
            return config.expected;
        }
        return null;
    }

    pub fn getInputInt(self: *Helper, bench_name: []const u8) i32 {
        if (self.getInput(bench_name)) |input_str| {
            return std.fmt.parseInt(i32, input_str, 10) catch 0;
        }
        return 0;
    }

    // Дополнительные методы для совместимости с C++ версией
    pub fn next_int(self: *Helper, max: i32) i32 {
        return self.nextInt(max);
    }

    pub fn next_int_range(self: *Helper, from: i32, to: i32) i32 {
        return self.nextIntRange(from, to);
    }

    pub fn next_float(self: *Helper, max: f64) f64 {
        return self.nextFloat(max);
    }

    pub fn checksum(self: *Helper, v: []const u8) u32 {
        return self.checksumString(v);
    }

    pub fn checksum_f64(self: *Helper, v: f64) u32 {
        return self.checksumFloat(v);
    }
};
