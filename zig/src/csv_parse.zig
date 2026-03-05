const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CsvParse = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    rows: usize,
    data: []const u8,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CsvParse {
        const self = try allocator.create(CsvParse);
        errdefer allocator.destroy(self);

        const rows = @as(usize, @intCast(helper.config_i64("CSV::Parse", "rows")));

        self.* = CsvParse{
            .allocator = allocator,
            .helper = helper,
            .rows = rows,
            .data = "",
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *CsvParse) void {
        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CsvParse) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CSV::Parse");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));

        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(self.allocator);

        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            const c = @as(u8, @intCast('A' + @mod(i, 26)));
            const x = self.helper.nextFloat(1.0);
            const z = self.helper.nextFloat(1.0);
            const y = self.helper.nextFloat(1.0);
            std.fmt.format(list.writer(self.allocator), "\"point {c}\\n, \"\"{d}\"\"\",{d:.10},,{d:.10},\"[{s}\\n, {d}]\",{d:.10}\n", .{
                c,
                @mod(i, 100),
                x,
                z,
                if (i % 2 == 0) "true" else "false",
                @mod(i, 100),
                y,
            }) catch return;
        }

        self.data = list.toOwnedSlice(self.allocator) catch {
            self.data = "";
            return;
        };
    }

    const Point = struct {
        x: f64,
        y: f64,
        z: f64,
    };

    fn parseCSVLine(line: []const u8) !Point {
        var fields: [6][]const u8 = undefined;
        var field_idx: usize = 0;

        var start: usize = 0;
        var in_quotes = false;

        for (line, 0..) |ch, i| {
            if (ch == '"') {
                in_quotes = !in_quotes;
            } else if (ch == ',' and !in_quotes) {
                if (field_idx < 6) {
                    fields[field_idx] = line[start..i];
                    field_idx += 1;
                    start = i + 1;
                }
            }
        }

        if (field_idx < 6) {
            fields[field_idx] = line[start..];
            field_idx += 1;
        }

        if (field_idx < 6) return error.InvalidCSV;

        const x = std.fmt.parseFloat(f64, fields[1]) catch return error.InvalidFloat;
        const z = std.fmt.parseFloat(f64, fields[3]) catch return error.InvalidFloat;
        const y = std.fmt.parseFloat(f64, fields[5]) catch return error.InvalidFloat;

        return Point{ .x = x, .y = y, .z = z };
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        if (self.data.len == 0) return;

        var points: std.ArrayList(Point) = .empty;
        defer points.deinit(self.allocator);

        var lines = std.mem.splitScalar(u8, self.data, '\n');

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            if (parseCSVLine(line)) |point| {
                points.append(self.allocator, point) catch continue;
            } else |_| {
                continue;
            }
        }

        if (points.items.len == 0) return;

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;

        for (points.items) |p| {
            x_sum += p.x;
            y_sum += p.y;
            z_sum += p.z;
        }

        const len = @as(f64, @floatFromInt(points.items.len));
        const avg_x = x_sum / len;
        const avg_y = y_sum / len;
        const avg_z = z_sum / len;

        self.result_val +%= self.helper.checksumFloat(avg_x);
        self.result_val +%= self.helper.checksumFloat(avg_y);
        self.result_val +%= self.helper.checksumFloat(avg_z);
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
