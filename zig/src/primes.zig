// src/primes.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math; // Для удобства

pub const Primes = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i32,
    result_val: u32,

    // Константа префикса
    const PREFIX: i32 = 32338;

    // Узел префиксного дерева
    const Node = struct {
        children: [10]?*Node = [_]?*Node{null} ** 10,
        is_terminal: bool = false,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Primes {
        const n = helper.getInputInt("Primes");

        const self = try allocator.create(Primes);
        errdefer allocator.destroy(self);

        self.* = Primes{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 5432, // Начальное значение как в C++ версии
        };
        return self;
    }

    pub fn deinit(self: *Primes) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Primes) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Оптимизированное решето Эратосфена с использованием ArrayListUnmanaged
    fn generatePrimes(self: *Primes) !std.ArrayListUnmanaged(i32) {
        const limit = self.n;

        // Если limit < 2, возвращаем пустой список
        if (limit < 2) {
            return std.ArrayListUnmanaged(i32){};
        }

        // Используем простой массив bool для решета
        const size = @as(usize, @intCast(limit + 1));
        var is_prime = try self.allocator.alloc(bool, size);
        defer self.allocator.free(is_prime);

        // Инициализируем все числа как простые (кроме 0 и 1)
        @memset(is_prime, true);
        if (size > 0) is_prime[0] = false;
        if (size > 1) is_prime[1] = false;

        // Классическое решето
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

        // Собираем простые числа
        var primes = std.ArrayListUnmanaged(i32){};

        // Предварительное резервирование памяти - упрощенная формула
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

        // Предварительно форматируем числа в строки
        var buffer: [16]u8 = undefined; // Максимум 10 цифр для i32

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

    // Освобождение памяти дерева (рекурсивно)
    fn freeTrie(self: *Primes, node: *Node) void {
        for (node.children) |child_opt| {
            if (child_opt) |child| {
                self.freeTrie(child);
            }
        }
        self.allocator.destroy(node);
    }

    // Поиск по префиксу с BFS
    fn findPrimesWithPrefix(self: *Primes, root: *Node, prefix: i32) !std.ArrayListUnmanaged(i32) {
        var buffer: [12]u8 = undefined;
        const prefix_str = try std.fmt.bufPrint(&buffer, "{d}", .{prefix});

        // Находим узел префикса
        var current: *Node = root;
        for (prefix_str) |digit_char| {
            const digit = digit_char - '0';

            if (current.children[digit]) |child| {
                current = child;
            } else {
                // Префикс не найден - возвращаем пустой список
                return std.ArrayListUnmanaged(i32){};
            }
        }

        // BFS обход
        var results = std.ArrayListUnmanaged(i32){};

        var bfs_queue = std.ArrayListUnmanaged(struct { node: *Node, number: i32 }){};
        defer bfs_queue.deinit(self.allocator);

        try bfs_queue.append(self.allocator, .{ .node = current, .number = prefix });

        while (bfs_queue.items.len > 0) {
            const item = bfs_queue.pop().?;
            const node = item.node;
            const number = item.number;

            if (node.is_terminal) {
                try results.append(self.allocator, number);
            }

            // Итерируем по всем возможным цифрам
            for (0..10) |digit| {
                if (node.children[digit]) |child| {
                    // Проверяем переполнение умножения
                    const new_number = math.mul(i32, number, 10) catch continue;
                    try bfs_queue.append(self.allocator, .{ .node = child, .number = new_number + @as(i32, @intCast(digit)) });
                }
            }
        }

        // Сортируем результаты
        std.mem.sort(i32, results.items, {}, std.sort.asc(i32));
        return results;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *Primes = @ptrCast(@alignCast(ptr));

        // 1. Генерация простых чисел
        var primes = self.generatePrimes() catch return;
        defer primes.deinit(self.allocator);

        // 2. Построение префиксного дерева
        const trie = self.buildTrie(primes.items) catch return;
        defer self.freeTrie(trie);

        // 3. Поиск по префиксу
        var results = self.findPrimesWithPrefix(trie, PREFIX) catch return;
        defer results.deinit(self.allocator);

        // 4. Вычисление результата
        self.result_val += @as(u32, @intCast(results.items.len));
        for (results.items) |prime| {
            self.result_val +%= @as(u32, @intCast(prime));
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Primes = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Primes = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
