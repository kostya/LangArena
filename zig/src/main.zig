const std = @import("std");

// Импортируем базовые модули
const benchmark = @import("benchmark.zig");
const Helper = @import("helper.zig").Helper;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var helper = try Helper.init(allocator);
    defer helper.deinit();

    // Получаем аргументы командной строки
    var args = std.process.args();
    _ = args.next(); // Пропускаем имя программы

    const config_path = args.next() orelse "test.js";
    try helper.loadConfig(allocator, config_path);

    const single_bench = args.next();

    try benchmark.runAllBenchmarks(allocator, &helper, single_bench);

    const f = std.fs.cwd().createFile("/tmp/recompile_marker", .{}) catch return;
    defer f.close();
    var buffer: [0]u8 = undefined;
    var writer = f.writer(&buffer);
    const io_writer = &writer.interface;
    io_writer.writeAll("RECOMPILE_MARKER_0") catch {};
}