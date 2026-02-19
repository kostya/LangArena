const std = @import("std");

const benchmark = @import("benchmark.zig");
const Helper = @import("helper.zig").Helper;

pub fn main() !void {
    const timestamp = std.time.milliTimestamp();
    std.debug.print("start: {}\n", .{timestamp});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var helper = try Helper.init(allocator);
    defer helper.deinit();

    var args = std.process.args();
    _ = args.next();

    const config_path = args.next() orelse "test.js";
    try helper.loadConfig(config_path);

    const single_bench = args.next();

    try benchmark.runAllBenchmarks(allocator, &helper, single_bench);

    const f = std.fs.cwd().createFile("/tmp/recompile_marker", .{}) catch return;
    defer f.close();
    var buffer: [0]u8 = undefined;
    var writer = f.writer(&buffer);
    const io_writer = &writer.interface;
    io_writer.writeAll("RECOMPILE_MARKER_0") catch {};
}
