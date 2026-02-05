const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const JsonGenerate = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    data: std.ArrayList(DataEntry),
    result_val: u32,
    result_str: std.ArrayList(u8),

    const DataEntry = struct {
        x: f64,
        y: f64,
        z: f64,
        name: []const u8,
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonGenerate {
        // Получаем n из конфигурации
        const n = helper.config_i64("JsonGenerate", "coords");

        const self = try allocator.create(JsonGenerate);
        errdefer allocator.destroy(self);

        self.* = JsonGenerate{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .data = std.ArrayList(DataEntry).empty,
            .result_val = 0,
            .result_str = std.ArrayList(u8).empty,
        };

        return self;
    }

    pub fn deinit(self: *JsonGenerate) void {
        // Освобождаем все скопированные строки имен
        for (self.data.items) |entry| {
            self.allocator.free(entry.name);
        }
        self.data.deinit(self.allocator);
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonGenerate) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "JsonGenerate");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем старые данные
        for (self.data.items) |entry| {
            allocator.free(entry.name);
        }
        self.data.clearAndFree(allocator);
        self.result_str.clearAndFree(allocator);
        self.result_val = 0;

        const n_usize = @as(usize, @intCast(self.n));

        // Заполняем данные как в C++ prepare()
        self.data.ensureTotalCapacity(allocator, n_usize) catch return;

        for (0..n_usize) |_| {
            const x = self.helper.nextFloat(1.0);
            const y = self.helper.nextFloat(1.0);
            const z = self.helper.nextFloat(1.0);

            var name_buf: [32]u8 = undefined;
            const name = std.fmt.bufPrint(&name_buf, "{d:.7} {d}", .{
                self.helper.nextFloat(1.0),
                self.helper.nextInt(10000),
            }) catch "0.0000000 0";

            // Копируем строку
            const name_copy = allocator.dupe(u8, name) catch return;

            self.data.append(allocator, .{
                .x = x,
                .y = y,
                .z = z,
                .name = name_copy,
            }) catch {
                allocator.free(name_copy);
                return;
            };
        }
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем строку для новой итерации
        self.result_str.clearRetainingCapacity();

        // Начинаем JSON
        self.result_str.appendSlice(allocator, "{\"coordinates\":[") catch return;

        // Генерируем JSON из подготовленных данных
        for (self.data.items, 0..) |entry, i| {
            if (i > 0) {
                self.result_str.append(allocator, ',') catch return;
            }

            var buffer: [128]u8 = undefined;
            const formatted = std.fmt.bufPrint(&buffer,
                "{{\"x\":{d:.8},\"y\":{d:.8},\"z\":{d:.8},\"name\":\"{s}\",\"opts\":{{\"1\":[1,true]}}}}",
                .{ entry.x, entry.y, entry.z, entry.name }
            ) catch return;

            self.result_str.appendSlice(allocator, formatted) catch return;
        }

        self.result_str.appendSlice(allocator, "],\"info\":\"some info\"}") catch return;

        // Проверяем как в C++ версии и увеличиваем result_val
        if (self.result_str.items.len >= 15 and
            std.mem.startsWith(u8, self.result_str.items, "{\"coordinates\":")) {
            self.result_val +%= 1; // &+= в C++
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    pub fn get_result(self: *JsonGenerate) []const u8 {
        return self.result_str.items;
    }
};