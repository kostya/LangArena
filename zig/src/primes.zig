const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const Primes = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    prefix: i64,
    result_val: u32, // Изменено на u32 как в C++

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    // Узел префиксного дерева
    const Node = struct {
        children: [10]?*Node = [_]?*Node{null} ** 10,
        is_terminal: bool = false,

        pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
            for (self.children) |child_opt| {
                if (child_opt) |child| {
                    child.deinit(allocator);
                    allocator.destroy(child);
                }
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Primes {
        const n = helper.config_i64("Primes", "limit");
        const prefix = helper.config_i64("Primes", "prefix");

        const self = try allocator.create(Primes);
        errdefer allocator.destroy(self);

        self.* = Primes{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .prefix = prefix,
            .result_val = 5432, // Начальное значение как в C++ версии
        };
        return self;
    }

    pub fn deinit(self: *Primes) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Primes) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Primes");
    }

    // Оптимизированное решето Эратосфена
    fn generatePrimes(self: *Primes) !std.ArrayListUnmanaged(i32) {
        const limit = @as(i32, @intCast(self.n));

        if (limit < 2) {
            return std.ArrayListUnmanaged(i32){};
        }

        const size = @as(usize, @intCast(limit + 1));
        var is_prime = try self.allocator.alloc(bool, size);
        defer self.allocator.free(is_prime);

        @memset(is_prime, true);
        if (size > 0) is_prime[0] = false;
        if (size > 1) is_prime[1] = false;

        const sqrt_limit_float = @sqrt(@as(f64, @floatFromInt(limit)));
        const sqrt_limit: i32 = @intFromFloat(sqrt_limit_float);

        var p: i32 = 2;
        while (p <= sqrt_limit) : (p += 1) {
            if (is_prime[@as(usize, @intCast(p))]) {
                var multiple = p * p;
                while (multiple <= limit) : (multiple += p) {
                    is_prime[@as(usize, @intCast(multiple))] = false;
                }
            }
        }

        var primes = std.ArrayListUnmanaged(i32){};
        const estimated_count = @as(usize, @intCast(@divFloor(limit, 2) + 100));

        try primes.ensureTotalCapacity(self.allocator, estimated_count);

        var i: usize = 2;
        while (i <= @as(usize, @intCast(limit))) : (i += 1) {
            if (is_prime[i]) {
                try primes.append(self.allocator, @as(i32, @intCast(i)));
            }
        }

        return primes;
    }

    // Построение префиксного дерева
    fn buildTrie(self: *Primes, primes: []const i32) !*Node {
        const root = try self.allocator.create(Node);
        root.* = Node{};

        var buffer: [16]u8 = undefined;

        for (primes) |prime| {
            const digits = std.fmt.bufPrint(&buffer, "{d}", .{prime}) catch unreachable;

            var current: *Node = root;
            for (digits) |digit_char| {
                const digit = digit_char - '0';

                if (current.children[digit] == null) {
                    const child = try self.allocator.create(Node);
                    child.* = Node{};
                    current.children[digit] = child;
                }
                current = current.children[digit].?;
            }
            current.is_terminal = true;
        }

        return root;
    }

    // Поиск по префиксу с BFS
    fn findPrimesWithPrefix(self: *Primes, root: *Node, prefix: i64) !std.ArrayListUnmanaged(i32) {
        var buffer: [12]u8 = undefined;
        const prefix_str = try std.fmt.bufPrint(&buffer, "{d}", .{prefix});

        var current: *Node = root;
        for (prefix_str) |digit_char| {
            const digit = digit_char - '0';

            if (current.children[digit]) |child| {
                current = child;
            } else {
                return std.ArrayListUnmanaged(i32){};
            }
        }

        var results = std.ArrayListUnmanaged(i32){};

        var bfs_queue = std.ArrayListUnmanaged(struct { node: *Node, number: i32 }){};
        defer bfs_queue.deinit(self.allocator);

        try bfs_queue.append(self.allocator, .{ .node = current, .number = @as(i32, @intCast(prefix)) });

        while (bfs_queue.items.len > 0) {
            const item = bfs_queue.pop().?;
            const node = item.node;
            const number = item.number;

            if (node.is_terminal) {
                try results.append(self.allocator, number);
            }

            for (0..10) |digit| {
                if (node.children[digit]) |child| {
                    const new_number = math.mul(i32, number, 10) catch continue;
                    try bfs_queue.append(self.allocator, .{ .node = child, .number = new_number + @as(i32, @intCast(digit)) });
                }
            }
        }

        std.mem.sort(i32, results.items, {}, std.sort.asc(i32));
        return results;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *Primes = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        // 1. Генерация простых чисел
        var primes = self.generatePrimes() catch return;
        defer primes.deinit(self.allocator);

        // 2. Построение префиксного дерева
        const trie = self.buildTrie(primes.items) catch return;
        defer {
            trie.deinit(self.allocator);
            self.allocator.destroy(trie);
        }

        // 3. Поиск по префиксу
        var results = self.findPrimesWithPrefix(trie, self.prefix) catch return;
        defer results.deinit(self.allocator);

        // 4. Вычисление результата как в C++
        self.result_val += @as(u32, @intCast(results.items.len));
        for (results.items) |prime| {
            self.result_val +%= @as(u32, @intCast(prime));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *Primes = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Primes = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};