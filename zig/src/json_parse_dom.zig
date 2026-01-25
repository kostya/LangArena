// src/json_parse_dom.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const JsonParseDom = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: u32,
    n: i32,
    text_allocated: bool,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonParseDom {
        const n = helper.getInputInt("JsonParseDom");

        const self = try allocator.create(JsonParseDom);
        errdefer allocator.destroy(self);

        self.* = JsonParseDom{
            .allocator = allocator,
            .helper = helper,
            .text = "",
            .result_val = 0,
            .n = n,
            .text_allocated = false,
        };

        return self;
    }

    pub fn deinit(self: *JsonParseDom) void {
        if (self.text_allocated) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonParseDom) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));

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
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));

        const json_text = self.text;
        if (json_text.len == 0) {
            self.result_val = 0;
            return;
        }

        // Парсим в динамическое значение (DOM дерево)
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_text, .{}) catch return;
        defer parsed.deinit();

        const root = parsed.value;

        // Проверяем, что это объект
        if (root != .object) {
            return;
        }

        // Ищем поле "coordinates" в DOM
        const coordinates_field = root.object.get("coordinates") orelse return;

        // Проверяем, что это массив
        if (coordinates_field != .array) {
            return;
        }

        const coordinates = coordinates_field.array.items;

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;
        var len: usize = 0;

        // Итерируем по DOM дереву
        for (coordinates) |coord_item| {
            // Проверяем, что элемент - объект
            if (coord_item != .object) continue;

            const coord_obj = coord_item.object;

            // Извлекаем значения из DOM
            const x_val = coord_obj.get("x") orelse continue;
            const y_val = coord_obj.get("y") orelse continue;
            const z_val = coord_obj.get("z") orelse continue;

            // Конвертируем значения в f64
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
            self.result_val = 0;
            return;
        }

        // Вычисляем средние
        const avg_len = @as(f64, @floatFromInt(len));
        const avg_x = x_sum / avg_len;
        const avg_y = y_sum / avg_len;
        const avg_z = z_sum / avg_len;

        // Вычисляем checksum
        const sum1 = self.helper.checksumFloat(avg_x);
        const sum2 = self.helper.checksumFloat(avg_y);
        const sum3 = self.helper.checksumFloat(avg_z);

        self.result_val = sum1 +% sum2 +% sum3;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonParseDom = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
