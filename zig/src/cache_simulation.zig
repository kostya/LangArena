const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CacheSimulation = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    result_val: u32,
    values_size: i64,
    cache_size: i64,
    cache: FastLRUCache,
    hits: u32,
    misses: u32,

    const CacheNode = struct {
        key: i32,
        value: i64,
        prev: ?*CacheNode,
        next: ?*CacheNode,
    };

    const FastLRUCache = struct {
        capacity: usize,
        nodes: []CacheNode,
        map: std.AutoHashMapUnmanaged(i32, *CacheNode),
        free_stack: []usize,
        free_top: usize,
        head: ?*CacheNode,
        tail: ?*CacheNode,
        size: usize,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, capacity: usize) !FastLRUCache {
            const nodes = try allocator.alloc(CacheNode, capacity);

            const free_stack = try allocator.alloc(usize, capacity);
            for (0..capacity) |i| {
                free_stack[i] = i;
            }

            return FastLRUCache{
                .capacity = capacity,
                .nodes = nodes,
                .map = .{},
                .free_stack = free_stack,
                .free_top = capacity,
                .head = null,
                .tail = null,
                .size = 0,
                .allocator = allocator,
            };
        }

        fn deinit(self: *FastLRUCache) void {
            self.map.deinit(self.allocator);
            self.allocator.free(self.nodes);
            self.allocator.free(self.free_stack);
        }

        fn allocNode(self: *FastLRUCache) ?*CacheNode {
            if (self.free_top == 0) return null;
            self.free_top -= 1;
            const index = self.free_stack[self.free_top];
            return &self.nodes[index];
        }

        fn freeNode(self: *FastLRUCache, node: *CacheNode) void {
            const index = (@intFromPtr(node) - @intFromPtr(self.nodes.ptr)) / @sizeOf(CacheNode);
            self.free_stack[self.free_top] = index;
            self.free_top += 1;
        }

        fn moveToFront(self: *FastLRUCache, node: *CacheNode) void {
            if (node == self.head) return;

            if (node.prev) |prev| prev.next = node.next;
            if (node.next) |next| next.prev = node.prev;

            if (node == self.tail) self.tail = node.prev;

            node.prev = null;
            node.next = self.head;
            if (self.head) |head| head.prev = node;
            self.head = node;

            if (self.tail == null) self.tail = node;
        }

        fn addToFront(self: *FastLRUCache, node: *CacheNode) void {
            node.next = self.head;
            node.prev = null;
            if (self.head) |head| head.prev = node;
            self.head = node;
            if (self.tail == null) self.tail = node;
        }

        fn removeOldest(self: *FastLRUCache) void {
            const oldest = self.tail orelse return;

            _ = self.map.remove(oldest.key);

            if (oldest.prev) |prev| {
                prev.next = null;
                self.tail = prev;
            } else {
                self.head = null;
                self.tail = null;
            }

            self.freeNode(oldest);
            self.size -= 1;
        }

        fn get(self: *FastLRUCache, key_num: i32) ?i64 {
            const node = self.map.get(key_num) orelse return null;

            self.moveToFront(node);
            return node.value;
        }

        fn put(self: *FastLRUCache, key_num: i32, value_num: i64) !void {
            if (self.map.get(key_num)) |node| {
                node.value = value_num;
                self.moveToFront(node);
                return;
            }

            if (self.size >= self.capacity) {
                self.removeOldest();
            }

            const node = self.allocNode() orelse return error.OutOfMemory;

            node.key = key_num;
            node.value = value_num;
            node.prev = null;
            node.next = null;

            try self.map.put(self.allocator, key_num, node);
            self.addToFront(node);
            self.size += 1;
        }

        fn getSize(self: *FastLRUCache) usize {
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

        const values_size = helper.config_i64("Etc::CacheSimulation", "values");
        const cache_size = helper.config_i64("Etc::CacheSimulation", "size");

        self.* = CacheSimulation{
            .allocator = allocator,
            .helper = helper,
            .result_val = 5432,
            .values_size = values_size,
            .cache_size = cache_size,
            .cache = try FastLRUCache.init(allocator, @intCast(cache_size)),
            .hits = 0,
            .misses = 0,
        };

        return self;
    }

    pub fn deinit(self: *CacheSimulation) void {
        self.cache.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CacheSimulation) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Etc::CacheSimulation");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.hits = 0;
        self.misses = 0;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));

        var n: usize = 0;
        while (n < 1000) {
            const key_num = self.helper.nextInt(@intCast(self.values_size));

            if (self.cache.get(key_num)) |_| {
                self.hits += 1;
                self.cache.put(key_num, iteration_id) catch return;
            } else {
                self.misses += 1;
                self.cache.put(key_num, iteration_id) catch return;
            }
            n += 1;
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        var final_result: u32 = self.result_val;
        final_result = (final_result << 5) + self.hits;
        final_result = (final_result << 5) + self.misses;
        final_result = (final_result << 5) + @as(u32, @intCast(self.cache.getSize()));
        return final_result;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CacheSimulation = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
