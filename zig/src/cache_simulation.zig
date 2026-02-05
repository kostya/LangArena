const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CacheSimulation = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    result_val: u32,
    values_size: i64,
    cache_size: i64,
    cache: ?FastLRUCache,
    hits: u32,
    misses: u32,

    // Node для DoublyLinkedList
    const CacheNode = struct {
        key: []const u8,
        next: ?*CacheNode = null,
        prev: ?*CacheNode = null,
    };

    // Внутренняя структура для map
    const CacheEntry = struct {
        value: []const u8,
        node: *CacheNode,
    };

    // FastLRUCache implementation
    const FastLRUCache = struct {
        allocator: std.mem.Allocator,
        capacity: usize,
        map: std.StringHashMap(CacheEntry),
        lru_head: ?*CacheNode = null,
        lru_tail: ?*CacheNode = null,
        size: usize = 0,

        fn init(allocator: std.mem.Allocator, capacity: usize) !FastLRUCache {
            const map = std.StringHashMap(CacheEntry).init(allocator);

            return FastLRUCache{
                .allocator = allocator,
                .capacity = capacity,
                .map = map,
                .lru_head = null,
                .lru_tail = null,
                .size = 0,
            };
        }

        fn deinit(self: *FastLRUCache) void {
            // Освобождаем все узлы
            var current = self.lru_head;
            while (current) |node| {
                const next = node.next;
                self.allocator.free(node.key); // Освобождаем ключ
                self.allocator.destroy(node);
                current = next;
            }

            // НЕ освобождаем ключи здесь - они уже освобождены выше
            // Освобождаем только значения из map
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.value_ptr.value); // Освобождаем только значение
                // Ключ НЕ освобождаем - он уже освобожден в цикле узлов
            }
            self.map.deinit();
        }

        fn removeNode(self: *FastLRUCache, node: *CacheNode) void {
            if (node.prev) |prev| {
                prev.next = node.next;
            } else {
                self.lru_head = node.next;
            }

            if (node.next) |next| {
                next.prev = node.prev;
            } else {
                self.lru_tail = node.prev;
            }

            node.next = null;
            node.prev = null;
        }

        fn prependNode(self: *FastLRUCache, node: *CacheNode) void {
            node.next = self.lru_head;
            node.prev = null;

            if (self.lru_head) |head| {
                head.prev = node;
            }

            self.lru_head = node;

            if (self.lru_tail == null) {
                self.lru_tail = node;
            }
        }

        fn get(self: *FastLRUCache, key: []const u8) bool {
            if (self.map.getPtr(key)) |entry| {
                // Move to front (most recent)
                self.removeNode(entry.node);
                self.prependNode(entry.node);
                return true;
            }
            return false;
        }

        fn put(self: *FastLRUCache, key: []const u8, value: []const u8) !void {
            if (self.map.getPtr(key)) |entry| {
                // Update existing
                self.removeNode(entry.node);
                self.prependNode(entry.node);

                // Free old value, allocate new
                self.allocator.free(entry.value);
                const value_copy = try self.allocator.dupe(u8, value);
                entry.value = value_copy;
                return;
            }

            // Remove oldest if at capacity
            if (self.size >= self.capacity) {
                if (self.lru_tail) |oldest| {
                    if (self.map.fetchRemove(oldest.key)) |old_entry| {
                        self.removeNode(oldest);
                        self.allocator.free(old_entry.key);
                        self.allocator.free(old_entry.value.value);
                        self.allocator.destroy(oldest);
                        self.size -= 1;
                    }
                }
            }

            // Insert new
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);

            const value_copy = try self.allocator.dupe(u8, value);
            errdefer self.allocator.free(value_copy);

            const node = try self.allocator.create(CacheNode);
            errdefer self.allocator.destroy(node);
            node.* = CacheNode{
                .key = key_copy,
                .next = null,
                .prev = null,
            };

            self.prependNode(node);
            self.size += 1;

            try self.map.put(key_copy, CacheEntry{
                .value = value_copy,
                .node = node,
            });
        }

        fn cacheSize(self: *FastLRUCache) usize {
            return self.size;
        }
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
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
            .cache = null,
            .hits = 0,
            .misses = 0,
        };

        return self;
    }

    pub fn deinit(self: *CacheSimulation) void {
        if (self.cache) |*cache| {
            cache.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CacheSimulation) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CacheSimulation");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем старый кэш
        if (self.cache) |*cache| {
            cache.deinit();
            self.cache = null;
        }

        // Получаем конфигурацию
        self.values_size = self.helper.config_i64("CacheSimulation", "values");
        self.cache_size = self.helper.config_i64("CacheSimulation", "size");

        // Сбрасываем счетчики
        self.hits = 0;
        self.misses = 0;

        // Создаем новый LRU кэш
        const cache = FastLRUCache.init(allocator, @as(usize, @intCast(self.cache_size))) catch return;
        self.cache = cache;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        if (self.cache == null) {
            return;
        }

        const cache = &self.cache.?;
        var key_buf: [32]u8 = undefined;
        var val_buf: [32]u8 = undefined;

        // Генерируем ключ
        const key_num = self.helper.nextInt(@as(i32, @intCast(self.values_size)));
        const key = std.fmt.bufPrint(&key_buf, "item_{}", .{key_num}) catch return;

        if (cache.get(key)) {
            // Hit - обновляем значение
            self.hits += 1;
            const value = std.fmt.bufPrint(&val_buf, "updated_{}", .{iteration_id}) catch return;
            cache.put(key, value) catch return;
        } else {
            // Miss - добавляем новое значение
            self.misses += 1;
            const value = std.fmt.bufPrint(&val_buf, "new_{}", .{iteration_id}) catch return;
            cache.put(key, value) catch return;
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        // Формула как в C++ версии
        var final_result: u32 = self.result_val;
        final_result = (final_result << 5) + self.hits;
        final_result = (final_result << 5) + self.misses;

        if (self.cache) |*cache| {
            final_result = (final_result << 5) + @as(u32, @intCast(cache.cacheSize()));
        }

        return final_result;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};