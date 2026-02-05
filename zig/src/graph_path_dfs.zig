const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GraphPathDFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: std.ArrayList(std.ArrayList(usize)), // Изменено на ArrayList
    pairs: std.ArrayList([2]usize), // Изменено на ArrayList
    result_val: u32,
    prepared: bool, // Добавлено

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathDFS {
        const self = try allocator.create(GraphPathDFS);
        errdefer allocator.destroy(self);

        self.* = GraphPathDFS{
            .allocator = allocator,
            .helper = helper,
            .graph = .{},
            .pairs = .{},
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDFS) void {
        const allocator = self.allocator;

        for (self.graph.items) |*neighbors| {
            neighbors.deinit(allocator);
        }
        self.graph.deinit(allocator);
        self.pairs.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GraphPathDFS");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (!self.prepared) {
            const pairs_val = self.helper.config_i64("GraphPathDFS", "pairs");
            const vertices_val = self.helper.config_i64("GraphPathDFS", "vertices");

            const vertices = @as(usize, @intCast(vertices_val));
            const comps = @max(@as(usize, 10), vertices / 10000);

            // Очищаем старый граф
            for (self.graph.items) |*neighbors| {
                neighbors.deinit(allocator);
            }
            self.graph.clearAndFree(allocator);
            self.pairs.clearAndFree(allocator);
            self.result_val = 0;

            // Инициализируем списки смежности
            self.graph.ensureTotalCapacity(allocator, vertices) catch return;
            for (0..vertices) |_| {
                self.graph.append(allocator, .{}) catch return;
            }

            const component_size = vertices / comps;

            // Генерируем граф
            for (0..comps) |c| {
                const start_idx = c * component_size;
                const end_idx = if (c == comps - 1) vertices else (c + 1) * component_size;

                var i = start_idx + 1;
                while (i < end_idx) : (i += 1) {
                    const parent = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(i - start_idx)))));
                    self.graph.items[i].append(allocator, parent) catch return;
                    self.graph.items[parent].append(allocator, i) catch return;
                }

                const extra_edges = component_size * 2;
                for (0..extra_edges) |_| {
                    const u = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    const v = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    if (u != v) {
                        self.graph.items[u].append(allocator, v) catch return;
                        self.graph.items[v].append(allocator, u) catch return;
                    }
                }
            }

            // Генерируем пары
            const pairs_count = @as(usize, @intCast(pairs_val));
            self.pairs.ensureTotalCapacity(allocator, pairs_count) catch return;

            const component_size_for_pairs = vertices / 10;

            for (0..pairs_count) |_| {
                if (self.helper.nextInt(100) < 70) {
                    const component = @as(usize, @intCast(self.helper.nextInt(10)));
                    const start = component * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                    var end: usize = undefined;
                    while (true) {
                        end = component * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                        if (end != start) break;
                    }
                    self.pairs.appendAssumeCapacity(.{ start, end });
                } else {
                    const c1 = @as(usize, @intCast(self.helper.nextInt(10)));
                    var c2: usize = undefined;
                    while (true) {
                        c2 = @as(usize, @intCast(self.helper.nextInt(10)));
                        if (c2 != c1) break;
                    }
                    const start = c1 * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                    const end = c2 * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                    self.pairs.appendAssumeCapacity(.{ start, end });
                }
            }

            self.prepared = true;
        }
    }

    // DFS для поиска кратчайшего пути (как в C++ версии)
    fn dfsFindPath(self: *const GraphPathDFS, start: usize, target: usize, allocator: std.mem.Allocator) i32 {
        if (start == target) return 0;

        const vertices = self.graph.items.len;

        // visited как вектор байтов (uint8_t) как в C++
        const visited = allocator.alloc(u8, vertices) catch return -1;
        defer allocator.free(visited);
        @memset(visited, 0);

        // stack как в C++: std::stack<std::pair<int, int>>
        var stack = std.ArrayList([2]i32){};
        defer stack.deinit(allocator);

        const INF = std.math.maxInt(i32);
        var best_path: i32 = INF;

        stack.append(allocator, .{ @as(i32, @intCast(start)), 0 }) catch return -1;

        while (stack.items.len > 0) {
            // pop() возвращает optional, разворачиваем
            const current_opt = stack.pop();
            const current = current_opt orelse break;
            const vertex = current[0];
            const distance = current[1];

            if (visited[@as(usize, @intCast(vertex))] == 1 or distance >= best_path) continue;
            visited[@as(usize, @intCast(vertex))] = 1;

            const neighbors = self.graph.items[@as(usize, @intCast(vertex))].items;
            for (neighbors) |neighbor| {
                if (neighbor == target) {
                    if (distance + 1 < best_path) {
                        best_path = distance + 1;
                    }
                } else if (visited[neighbor] == 0) {
                    stack.append(allocator, .{ @as(i32, @intCast(neighbor)), distance + 1 }) catch return -1;
                }
            }
        }

        return if (best_path == INF) -1 else best_path;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        var total_length: i32 = 0;

        // Используем arena для временных аллокаций DFS
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        for (self.pairs.items) |pair| {
            const length = self.dfsFindPath(pair[0], pair[1], arena_allocator);
            total_length += length;
        }

        self.result_val +%= @as(u32, @intCast(total_length));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};