// src/json_parse_mapping.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const JsonParseMapping = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: u32,
    n: i32,
    text_allocated: bool,

    const Coordinate = struct {
        x: f64,
        y: f64,
        z: f64,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonParseMapping {
        const n = helper.getInputInt("JsonParseMapping");

        const self = try allocator.create(JsonParseMapping);
        errdefer allocator.destroy(self);

        self.* = JsonParseMapping{
            .allocator = allocator,
            .helper = helper,
            .text = "",
            .result_val = 0,
            .n = n,
            .text_allocated = false,
        };

        return self;
    }

    pub fn deinit(self: *JsonParseMapping) void {
        if (self.text_allocated) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonParseMapping) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));

        if (self.text_allocated) {
            self.allocator.free(self.text);
            self.text_allocated = false;
        }

        // Используем JsonGenerate для генерации JSON
        const JsonGenerate = @import("json_generate.zig").JsonGenerate;
        var jg = JsonGenerate.init(self.allocator, self.helper) catch return;
        defer jg.deinit();

        jg.n = self.n;

        // Генерируем JSON
        const json_text = jg.generateJson() catch return;

        // Копируем результат
        self.text = self.allocator.dupe(u8, json_text) catch return;
        self.text_allocated = true;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));

        const json_text = self.text;
        if (json_text.len == 0) {
            self.result_val = 0;
            return;
        }

        // Парсим JSON с поддержкой игнорирования лишних полей
        var parsed = std.json.parseFromSlice(struct {
            coordinates: []struct {
                x: f64,
                y: f64,
                z: f64,
                // Игнорируем остальные поля
            },
        }, self.allocator, json_text, .{ .ignore_unknown_fields = true }) catch |err| {
            std.debug.print("Parse error: {}\n", .{err});
            return;
        };
        defer parsed.deinit();

        const coords = parsed.value.coordinates;

        if (coords.len == 0) {
            self.result_val = 0;
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

        // Вычисляем checksum
        const sum1 = self.helper.checksumFloat(avg_x);
        const sum2 = self.helper.checksumFloat(avg_y);
        const sum3 = self.helper.checksumFloat(avg_z);

        self.result_val = sum1 +% sum2 +% sum3; // Используем +% для переполнения без паники
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
