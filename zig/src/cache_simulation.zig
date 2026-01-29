const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CacheSimulation = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    result_val: u32,
    values_size: i64,
    cache_size: i64,
    cache: std.StringHashMap(CacheEntry),
    hits: u32,
    misses: u32,

    const CacheEntry = struct {
        value: []const u8,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CacheSimulation {
        const self = try allocator.create(CacheSimulation);
        errdefer allocator.destroy(self);

        self.* = CacheSimulation{
            .allocator = allocator,
            .helper = helper,
            .result_val = 5432,
            .values_size = 0,
            .cache_size = 0,
            .cache = std.StringHashMap(CacheEntry).init(allocator),
            .hits = 0,
            .misses = 0,
        };

        return self;
    }

    pub fn deinit(self: *CacheSimulation) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CacheSimulation) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        if (self.values_size == 0) {
            self.values_size = self.helper.config_i64("CacheSimulation", "values");
            self.cache_size = self.helper.config_i64("CacheSimulation", "size");

            // Очищаем кэш
            var iter = self.cache.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.value);
            }
            self.cache.clearAndFree();
            self.hits = 0;
            self.misses = 0;
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "item_{}", .{self.helper.nextInt(@as(i32, @intCast(self.values_size)))}) catch return;

        var val_buf: [32]u8 = undefined;

        if (self.cache.get(key)) |_| {
            self.hits += 1;
            const value = std.fmt.bufPrint(&val_buf, "updated_{}", .{iteration_id}) catch return;

            // Обновляем значение
            if (self.cache.getPtr(key)) |entry| {
                self.allocator.free(entry.value);
                entry.value = self.allocator.dupe(u8, value) catch return;
            }
        } else {
            self.misses += 1;
            const value = std.fmt.bufPrint(&val_buf, "new_{}", .{iteration_id}) catch return;

            // Удаляем самый старый элемент если кэш полон
            if (self.cache.count() >= @as(usize, @intCast(self.cache_size))) {
                var iter = self.cache.iterator();
                if (iter.next()) |entry| {
                    const old_key = entry.key_ptr.*;
                    const old_value = entry.value_ptr.value;
                    _ = self.cache.remove(old_key);
                    self.allocator.free(old_key);
                    self.allocator.free(old_value);
                }
            }

            // Добавляем новый элемент
            const key_copy = self.allocator.dupe(u8, key) catch return;
            const value_copy = self.allocator.dupe(u8, value) catch return;
            self.cache.put(key_copy, .{ .value = value_copy }) catch {
                self.allocator.free(key_copy);
                self.allocator.free(value_copy);
                return;
            };
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        var final_result: u32 = self.result_val;
        final_result = (final_result << 5) + self.hits;
        final_result = (final_result << 5) + self.misses;
        final_result = (final_result << 5) + @as(u32, @intCast(self.cache.count()));

        return final_result;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};