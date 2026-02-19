const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const JsonGenerate = @import("json_generate.zig").JsonGenerate;

pub const JsonParseDom = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonParseDom {
        const self = try allocator.create(JsonParseDom);
        errdefer allocator.destroy(self);

        self.* = JsonParseDom{
            .allocator = allocator,
            .helper = helper,
            .text = "",
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *JsonParseDom) void {
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonParseDom) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "JsonParseDom");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));

        var jg = JsonGenerate.init(self.allocator, self.helper) catch return;
        defer jg.deinit();

        jg.n = self.helper.config_i64("JsonParseDom", "coords");

        var benchmark = jg.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        const result = jg.get_result();
        if (result.len > 0) {
            self.text = self.allocator.dupe(u8, result) catch "";
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const json_text = self.text;
        if (json_text.len == 0) {
            return;
        }

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_text, .{}) catch return;
        defer parsed.deinit();

        const root = parsed.value;

        if (root != .object) {
            return;
        }

        const coordinates = root.object.get("coordinates") orelse return;
        if (coordinates != .array) {
            return;
        }

        const coords_array = coordinates.array.items;
        if (coords_array.len == 0) {
            return;
        }

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;

        for (coords_array) |item| {
            if (item != .object) continue;

            const obj = item.object;

            const x_val = obj.get("x") orelse continue;
            const y_val = obj.get("y") orelse continue;
            const z_val = obj.get("z") orelse continue;

            const x: f64 = switch (x_val) {
                .integer => |val| @floatFromInt(val),
                .float => |val| val,
                else => continue,
            };

            const y: f64 = switch (y_val) {
                .integer => |val| @floatFromInt(val),
                .float => |val| val,
                else => continue,
            };

            const z: f64 = switch (z_val) {
                .integer => |val| @floatFromInt(val),
                .float => |val| val,
                else => continue,
            };

            x_sum += x;
            y_sum += y;
            z_sum += z;
        }

        const len = @as(f64, @floatFromInt(coords_array.len));
        const avg_x = x_sum / len;
        const avg_y = y_sum / len;
        const avg_z = z_sum / len;

        self.result_val +%= self.helper.checksumFloat(avg_x);
        self.result_val +%= self.helper.checksumFloat(avg_y);
        self.result_val +%= self.helper.checksumFloat(avg_z);
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
