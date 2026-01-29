const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const JsonGenerate = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_str: std.ArrayListUnmanaged(u8),
    result_val: u32, // Изменено на u32

    const Coordinate = struct {
        x: f64,
        y: f64,
        z: f64,
        name: []const u8,
        opts: struct {
            first: i32 = 1,
            second: bool = true,
        },
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonGenerate {
        const n = helper.config_i64("JsonGenerate", "coords");

        const self = try allocator.create(JsonGenerate);
        errdefer allocator.destroy(self);

        self.* = JsonGenerate{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_str = .{},
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *JsonGenerate) void {
        self.result_str.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonGenerate) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        self.result_str.clearAndFree(self.allocator);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const allocator = self.allocator;
        const n = @as(usize, @intCast(self.n));

        // Очищаем предыдущий результат
        self.result_str.clearRetainingCapacity();

        var buffer: [32]u8 = undefined;

        // Начинаем JSON
        self.result_str.appendSlice(allocator, "{\"coordinates\":[") catch return;

        // Генерируем координаты
        for (0..n) |i| {
            if (i > 0) {
                self.result_str.append(allocator, ',') catch return;
            }

            const x = self.helper.nextFloat(1.0);
            const y = self.helper.nextFloat(1.0);
            const z = self.helper.nextFloat(1.0);

            const name = std.fmt.bufPrint(&buffer, "{d:.7} {d}", .{
                self.helper.nextFloat(1.0),
                self.helper.nextInt(10000),
            }) catch "0.0000000 0";

            // Форматируем координату как в C++ версии
            const formatted = std.fmt.bufPrint(&buffer, "{{\"x\":{d:.8},\"y\":{d:.8},\"z\":{d:.8},\"name\":\"{s}\",\"opts\":{{\"1\":[1,true]}}}}", .{ x, y, z, name }) catch return;

            self.result_str.appendSlice(allocator, formatted) catch return;
        }

        self.result_str.appendSlice(allocator, "],\"info\":\"some info\"}") catch return;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));

        // Берем первые 500 символов как в C++ версии
        var truncated = self.result_str.items;
        if (truncated.len >= 500) {
            truncated = truncated[0..499];
        }

        return self.helper.checksumString(truncated);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    pub fn get_result(self: *JsonGenerate) []const u8 {
        return self.result_str.items;
    }
};