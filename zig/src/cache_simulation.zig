// src/cache_simulation.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

// Node для DoublyLinkedList (выносим наверх)
const CacheNode = struct {
    key: []const u8,
    next: ?*CacheNode = null,
    prev: ?*CacheNode = null,
};

// Внутренняя структура для map (выносим наверх)
const CacheEntry = struct {
    value: []const u8,
    node: *CacheNode,
};

// FastLRUCache implementation (выносим наверх)
const FastLRUCache = struct {
    allocator: std.mem.Allocator,
    capacity: usize,
    map: std.StringHashMap(CacheEntry),
    lru_head: ?*CacheNode = null,
    lru_tail: ?*CacheNode = null,
    size: usize = 0,

    fn init(allocator: std.mem.Allocator, capacity: usize) !FastLRUCache {
        return FastLRUCache{
            .allocator = allocator,
            .capacity = capacity,
            .map = std.StringHashMap(CacheEntry).init(allocator),
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
            self.allocator.free(node.key);
            self.allocator.destroy(node);
            current = next;
        }

        // Освобождаем значения из map
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.value);
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
            entry.value = try self.allocator.dupe(u8, value);
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

pub const CacheSimulation = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    operations: i32,
    result_val: u64,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CacheSimulation {
        const operations = helper.getInputInt("CacheSimulation") * 1000;

        const self = try allocator.create(CacheSimulation);
        errdefer allocator.destroy(self);

        self.* = CacheSimulation{
            .allocator = allocator,
            .helper = helper,
            .operations = operations,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *CacheSimulation) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CacheSimulation) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        // 1. Создаём кэш напрямую, без arena
        var cache = FastLRUCache.init(self.allocator, 1000) catch return;
        defer cache.deinit(); // Освобождает всё при выходе

        var hits: u32 = 0;
        var misses: u32 = 0;

        // 2. Буферы для строк
        var key_buf: [32]u8 = undefined;
        var val_buf: [32]u8 = undefined;

        const operations_usize = @as(usize, @intCast(@max(self.operations, 0)));

        for (0..operations_usize) |i| {
            // Формируем ключ
            const key_num = self.helper.nextInt(2000);
            const key = std.fmt.bufPrint(&key_buf, "item_{}", .{key_num}) catch continue;

            if (cache.get(key)) {
                hits += 1;
                // Обновляем значение
                const value = std.fmt.bufPrint(&val_buf, "updated_{}", .{i}) catch continue;
                cache.put(key, value) catch continue;
            } else {
                misses += 1;
                const value = std.fmt.bufPrint(&val_buf, "new_{}", .{i}) catch continue;
                cache.put(key, value) catch continue;
            }
        }

        // 3. Формируем результат как в C++ (исправлено для Zig 0.15+)
        var result_str = std.ArrayList(u8){};
        defer result_str.deinit(self.allocator);

        const writer = result_str.writer(self.allocator);
        writer.print("hits:{}|misses:{}|size:{}", .{ hits, misses, cache.cacheSize() }) catch return;

        self.result_val = self.helper.checksumString(result_str.items);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};