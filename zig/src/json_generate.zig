// src/json_generate.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const JsonGenerate = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i32,
    result_val: i64,
    data: std.ArrayListUnmanaged(Coordinate),
    json_result: std.ArrayListUnmanaged(u8),

    // Определяем тип для opts один раз
    const OptEntry = struct { first: i32, second: bool };

    const Coordinate = struct {
        x: f64,
        y: f64,
        z: f64,
        name: []const u8,
        opts: std.StringArrayHashMapUnmanaged(OptEntry),

        pub fn deinit(self: *Coordinate, allocator: std.mem.Allocator) void {
            allocator.free(self.name);

            // Освобождаем ключи в opts
            var iter = self.opts.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
            }
            self.opts.deinit(allocator);
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*JsonGenerate {
        const n = helper.getInputInt("JsonGenerate");

        const self = try allocator.create(JsonGenerate);
        errdefer allocator.destroy(self);

        self.* = JsonGenerate{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
            .data = .{},
            .json_result = .{},
        };

        return self;
    }

    pub fn deinit(self: *JsonGenerate) void {
        // Освобождаем все координаты
        for (self.data.items) |*coord| {
            var mutable_coord: *Coordinate = @ptrCast(coord);
            mutable_coord.deinit(self.allocator);
        }
        self.data.deinit(self.allocator);
        self.json_result.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *JsonGenerate) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Функция для округления чисел с заданной точностью
    fn customRound(val: f64, precision: i32) f64 {
        const factor = std.math.pow(f64, 10.0, @as(f64, @floatFromInt(precision)));
        return @round(val * factor) / factor;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));

        // Очищаем старые данные если есть
        for (self.data.items) |*coord| {
            var mutable_coord: *Coordinate = @ptrCast(coord);
            mutable_coord.deinit(self.allocator);
        }
        self.data.clearAndFree(self.allocator);

        // Создаем новые данные
        for (0..@as(usize, @intCast(self.n))) |_| {
            const x = customRound(self.helper.nextFloat(1.0), 8);
            const y = customRound(self.helper.nextFloat(1.0), 8);
            const z = customRound(self.helper.nextFloat(1.0), 8);

            // Генерируем имя
            var name_buf: [64]u8 = undefined;
            const name = std.fmt.bufPrint(&name_buf, "{d:.7} {}", .{
                self.helper.nextFloat(1.0),
                self.helper.nextInt(10000),
            }) catch "0.0000000 0";

            const name_copy = self.allocator.dupe(u8, name) catch continue;

            // Создаем opts
            var opts = std.StringArrayHashMapUnmanaged(OptEntry){};
            const key = "1";
            const key_copy = self.allocator.dupe(u8, key) catch {
                self.allocator.free(name_copy);
                continue;
            };

            opts.put(self.allocator, key_copy, .{ .first = 1, .second = true }) catch {
                self.allocator.free(name_copy);
                self.allocator.free(key_copy);
                continue;
            };

            const coord = Coordinate{
                .x = x,
                .y = y,
                .z = z,
                .name = name_copy,
                .opts = opts,
            };

            self.data.append(self.allocator, coord) catch {
                var mutable_coord: *Coordinate = @constCast(&coord);
                mutable_coord.deinit(self.allocator);
                break;
            };
        }
    }

    pub fn runImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));

        // Очищаем предыдущий результат
        self.json_result.clearAndFree(self.allocator);

        // Создаем writer для записи JSON
        const writer = self.json_result.writer(self.allocator);

        // Генерируем JSON вручную
        writer.writeAll("{\"coordinates\":[") catch return;

        for (self.data.items, 0..) |coord, i| {
            if (i > 0) writer.writeAll(",") catch return;

            // Пишем координату
            writer.print("{{\"x\":{d:.8},\"y\":{d:.8},\"z\":{d:.8},\"name\":\"{s}\",\"opts\":{{\"1\":[1,true]}}}}", .{ coord.x, coord.y, coord.z, coord.name }) catch return;
        }

        writer.writeAll("],\"info\":\"some info\"}") catch return;

        // Результат как в оригинальном бенчмарке
        self.result_val = 1;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        return @as(u32, @intCast(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *JsonGenerate = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    // Заменяем метод generateJson на:
    pub fn generateJson(self: *JsonGenerate) ![]const u8 {
        // Очищаем предыдущий результат
        self.json_result.clearAndFree(self.allocator);

        // Подготавливаем данные
        var benchmark = self.asBenchmark();
        benchmark.prepare();

        // Запускаем генерацию через vtable
        benchmark.run();

        // Возвращаем результат
        return self.json_result.items;
    }
};
