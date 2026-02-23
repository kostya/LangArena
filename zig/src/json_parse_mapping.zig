const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const JsonGenerate = @import("json_generate.zig").JsonGenerate;

pub const JsonParseMapping = struct {
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonParseMapping {
        const self = try allocator.create(JsonParseMapping);
        errdefer allocator.destroy(self);

        self.* = JsonParseMapping{
            .allocator = allocator,
            .helper = helper,
            .text = "",
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *JsonParseMapping) void {
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonParseMapping) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Json::ParseMapping");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));

        var jg = JsonGenerate.init(self.allocator, self.helper) catch return;
        defer jg.deinit();

        jg.n = self.helper.config_i64("Json::ParseMapping", "coords");

        var benchmark = jg.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        const result = jg.get_result();
        if (result.len > 0) {
            self.text = self.allocator.dupe(u8, result) catch "";
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const json_text = self.text;
        if (json_text.len == 0) {
            return;
        }

        const Coord = struct {
            x: f64,
            y: f64,
            z: f64,
        };

        const JsonData = struct {
            coordinates: []Coord,
        };

        var parsed = std.json.parseFromSlice(JsonData, self.allocator, json_text, .{
            .ignore_unknown_fields = true,
        }) catch return;
        defer parsed.deinit();

        const coords = parsed.value.coordinates;
        if (coords.len == 0) {
            return;
        }

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;

        for (coords) |coord| {
            x_sum += coord.x;
            y_sum += coord.y;
            z_sum += coord.z;
        }

        const len = @as(f64, @floatFromInt(coords.len));
        const avg_x = x_sum / len;
        const avg_y = y_sum / len;
        const avg_z = z_sum / len;

        const sum1 = self.helper.checksumFloat(avg_x);
        const sum2 = self.helper.checksumFloat(avg_y);
        const sum3 = self.helper.checksumFloat(avg_z);
        const total = sum1 +% sum2 +% sum3;

        self.result_val +%= total;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
