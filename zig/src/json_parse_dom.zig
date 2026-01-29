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
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));

        // Освобождаем старый текст
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }

        // Используем JsonGenerate для генерации JSON
        var jg = JsonGenerate.init(self.allocator, self.helper) catch return;
        defer jg.deinit();

        jg.n = self.helper.config_i64("JsonParseDom", "coords");

        var benchmark = jg.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        // Копируем результат
        const json_text = jg.get_result();
        self.text = self.allocator.dupe(u8, json_text) catch "";
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const json_text = self.text;
        if (json_text.len == 0) {
            return;
        }

        // Парсим JSON с помощью std.json
        var parser = std.json.Parser.init(self.allocator, .{});
        defer parser.deinit();

        const value = parser.parse(json_text) catch return;
        defer value.deinit();

        // Ищем поле "coordinates" в DOM
        if (value != .object) {
            return;
        }

        const coordinates_field = value.object.get("coordinates") orelse return;
        if (coordinates_field != .array) {
            return;
        }

        const coordinates = coordinates_field.array.items;

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;
        var len: usize = 0;

        for (coordinates) |coord_item| {
            if (coord_item != .object) continue;

            const coord_obj = coord_item.object;

            const x_val = coord_obj.get("x") orelse continue;
            const y_val = coord_obj.get("y") orelse continue;
            const z_val = coord_obj.get("z") orelse continue;

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
            len += 1;
        }

        if (len == 0) {
            return;
        }

        const avg_len = @as(f64, @floatFromInt(len));
        const avg_x = x_sum / avg_len;
        const avg_y = y_sum / avg_len;
        const avg_z = z_sum / avg_len;

        // Вычисляем checksum как в C++ версии
        self.result_val += self.helper.checksumFloat(avg_x);
        self.result_val += self.helper.checksumFloat(avg_y);
        self.result_val += self.helper.checksumFloat(avg_z);
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