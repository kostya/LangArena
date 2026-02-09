const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

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
    config: json.Value,
    config_parsed: ?json.Parsed(json.Value) = null,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !Helper {
        return Helper{
            .last = INIT,
            .config = json.Value{ .null = {} },
            .config_parsed = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Helper) void {

        if (self.config_parsed) |*parsed| {
            parsed.deinit();
        }
    }

    pub fn reset(self: *Helper) void {
        self.last = INIT;
    }

    fn positiveMod(a: i32, b: i32) i32 {
        const rem = @rem(a, b);
        return if (rem < 0) rem + b else rem;
    }

    pub fn nextInt(self: *Helper, max: i32) i32 {

        self.last = positiveMod(self.last *% IA +% IC, IM);

        return @intFromFloat(@as(f64, @floatFromInt(self.last)) * @as(f64, @floatFromInt(max)) / @as(f64, @floatFromInt(IM)));
    }

    pub fn nextIntRange(self: *Helper, from: i32, to: i32) i32 {
        return self.nextInt(to - from + 1) + from;
    }

    pub fn nextFloat(self: *Helper, max: f64) f64 {

        self.last = positiveMod(self.last *% IA +% IC, IM);
        return max * @as(f64, @floatFromInt(self.last)) / @as(f64, @floatFromInt(IM));
    }

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

    pub fn loadConfig(self: *Helper, filename: ?[]const u8) !void {
        const default_filename = "test.js";
        const actual_filename = filename orelse default_filename;

        const file = try std.fs.cwd().openFile(actual_filename, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(content);

        if (self.config_parsed) |*parsed| {
            parsed.deinit();
        }

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content,
            .{ .ignore_unknown_fields = true }
        );

        self.config_parsed = parsed;
        self.config = parsed.value;
    }

    pub fn config_i64(self: *Helper, class_name: []const u8, field_name: []const u8) i64 {
        if (self.config == .object) {
            if (self.config.object.get(class_name)) |class_config| {
                if (class_config == .object) {
                    if (class_config.object.get(field_name)) |field_value| {
                        if (field_value == .integer) {
                            return field_value.integer;
                        } else if (field_value == .float) {
                            return @as(i64, @intFromFloat(field_value.float));
                        } else if (field_value == .string) {
                            return std.fmt.parseInt(i64, field_value.string, 10) catch 0;
                        }
                    }
                }
            }
        }
        std.debug.print("Config not found for {s}, field: {s}\n", .{ class_name, field_name });
        return 0;
    }

    pub fn config_s(self: *Helper, class_name: []const u8, field_name: []const u8) []const u8 {
        if (self.config == .object) {
            if (self.config.object.get(class_name)) |class_config| {
                if (class_config == .object) {
                    if (class_config.object.get(field_name)) |field_value| {
                        if (field_value == .string) {
                            return field_value.string;
                        }
                    }
                }
            }
        }
        std.debug.print("Config not found for {s}, field: {s}\n", .{ class_name, field_name });
        return "";
    }

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