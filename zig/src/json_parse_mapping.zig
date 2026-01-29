const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const JsonGenerate = @import("json_generate.zig").JsonGenerate;

pub const JsonParseMapping = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: u32,

    const Coordinate = struct {
        x: f64,
        y: f64,
        z: f64,
    };

    const ParsedJson = struct {
        coordinates: []Coordinate,
    };

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
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));

        // Освобождаем старый текст
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }

        // Используем JsonGenerate для генерации JSON
        var jg = JsonGenerate.init(self.allocator, self.helper) catch return;
        defer jg.deinit();

        jg.n = self.helper.config_i64("JsonParseMapping", "coords");

        var benchmark = jg.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        // Копируем результат
        const json_text = jg.get_result();
        self.text = self.allocator.dupe(u8, json_text) catch "";
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const json_text = self.text;
        if (json_text.len == 0) {
            return;
        }

        // Простой парсинг без использования сложных структур
        // Просто ищем координаты в тексте
        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;
        var len: usize = 0;

        var pos: usize = 0;
        while (pos < json_text.len) {
            // Ищем "x":
            if (std.mem.indexOfPos(u8, json_text, pos, "\"x\":") orelse break) |x_pos| {
                const start = x_pos + 4;
                const end = std.mem.indexOfPos(u8, json_text, start, ",") orelse break;

                if (std.fmt.parseFloat(f64, json_text[start..end]) catch null) |x| {
                    // Ищем "y":
                    if (std.mem.indexOfPos(u8, json_text, end, "\"y\":") orelse break) |y_pos| {
                        const y_start = y_pos + 4;
                        const y_end = std.mem.indexOfPos(u8, json_text, y_start, ",") orelse break;

                        if (std.fmt.parseFloat(f64, json_text[y_start..y_end]) catch null) |y| {
                            // Ищем "z":
                            if (std.mem.indexOfPos(u8, json_text, y_end, "\"z\":") orelse break) |z_pos| {
                                const z_start = z_pos + 4;
                                const z_end = std.mem.indexOfPos(u8, json_text, z_start, "}") orelse break;

                                if (std.fmt.parseFloat(f64, json_text[z_start..z_end]) catch null) |z| {
                                    x_sum += x;
                                    y_sum += y;
                                    z_sum += z;
                                    len += 1;
                                    pos = z_end;
                                    continue;
                                }
                            }
                        }
                    }
                }
                pos = end;
            } else {
                break;
            }
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
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonParseMapping = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};