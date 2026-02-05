const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GraphPathBFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: Graph,
    pairs: std.ArrayList([2]usize),
    result_val: u32, // Изменено на u32 как в C++
    prepared: bool,

    const Graph = struct {
        adj: std.ArrayList(std.ArrayList(usize)),
        vertices: usize,
        components: usize,

        fn init(allocator: std.mem.Allocator, vertices: usize, components: usize) !Graph {
            var adj = std.ArrayList(std.ArrayList(usize)){};
            try adj.ensureTotalCapacity(allocator, vertices);

            for (0..vertices) |_| {
                adj.appendAssumeCapacity(.{});
            }

            return Graph{
                .adj = adj,
                .vertices = vertices,
                .components = components,
            };
        }

        fn deinit(self: *Graph, allocator: std.mem.Allocator) void {
            for (self.adj.items) |*neighbors| {
                neighbors.deinit(allocator);
            }
            self.adj.deinit(allocator);
        }

        fn addEdge(self: *Graph, allocator: std.mem.Allocator, u: usize, v: usize) !void {
            try self.adj.items[u].append(allocator, v);
            try self.adj.items[v].append(allocator, u);
        }

        fn generateRandom(self: *Graph, allocator: std.mem.Allocator, helper: *Helper) !void {
            const component_size = self.vertices / self.components;

            for (0..self.components) |c| {
                const start_idx = c * component_size;
                const end_idx = if (c == self.components - 1) self.vertices else (c + 1) * component_size;

                var i = start_idx + 1;
                while (i < end_idx) : (i += 1) {
                    const parent = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(i - start_idx)))));
                    try self.addEdge(allocator, i, parent);
                }

                const extra_edges = component_size * 2;
                for (0..extra_edges) |_| {
                    const u = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    const v = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    if (u != v) {
                        try self.addEdge(allocator, u, v);
                    }
                }
            }
        }
    };

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathBFS {
        const self = try allocator.create(GraphPathBFS);
        errdefer allocator.destroy(self);

        self.* = GraphPathBFS{
            .allocator = allocator,
            .helper = helper,
            .graph = undefined,
            .pairs = .{},
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathBFS) void {
        const allocator = self.allocator;
        if (self.prepared) {
            self.graph.deinit(allocator);
            self.pairs.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathBFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GraphPathBFS");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (!self.prepared) {
            const pairs_val = self.helper.config_i64("GraphPathBFS", "pairs");
            const vertices_val = self.helper.config_i64("GraphPathBFS", "vertices");
            const comps = @max(@as(usize, 10), @as(usize, @intCast(vertices_val)) / 10000);

            // Создаем граф
            self.graph = Graph.init(allocator, @as(usize, @intCast(vertices_val)), comps) catch return;
            self.graph.generateRandom(allocator, self.helper) catch return;

            // Генерируем пары
            const pairs_count = @as(usize, @intCast(pairs_val));
            self.pairs.ensureTotalCapacity(allocator, pairs_count) catch return;

            const component_size_for_pairs = @as(usize, @intCast(vertices_val)) / 10;

            for (0..pairs_count) |_| {
                if (self.helper.nextInt(100) < 70) {
                    // В одной компоненте
                    const component = @as(usize, @intCast(self.helper.nextInt(10)));
                    const start = component * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                    var end: usize = undefined;
                    while (true) {
                        end = component * component_size_for_pairs + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size_for_pairs)))));
                        if (end != start) break;
                    }
                    self.pairs.appendAssumeCapacity(.{ start, end });
                } else {
                    // В разных компонентах
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

    fn bfsShortestPathOpt(self: *const GraphPathBFS, start: usize, target: usize, visited: []u8, queue: *std.ArrayList([2]i32), allocator: std.mem.Allocator) i32 {
        if (start == target) return 0;

        @memset(visited, 0);
        queue.clearRetainingCapacity();

        visited[start] = 1;
        queue.append(allocator, .{ @as(i32, @intCast(start)), 0 }) catch return -1;

        var front: usize = 0;
        while (front < queue.items.len) {
            const current = queue.items[front];
            front += 1;

            for (self.graph.adj.items[@as(usize, @intCast(current[0]))].items) |neighbor| {
                if (neighbor == target) return current[1] + 1;

                if (visited[neighbor] == 0) {
                    visited[neighbor] = 1;
                    queue.append(allocator, .{ @as(i32, @intCast(neighbor)), current[1] + 1 }) catch return -1;
                }
            }
        }

        return -1;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        var total_length: i32 = 0;

        // Используем arena для временных аллокаций
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Предварительно аллоцировать visited и queue
        const visited = arena_allocator.alloc(u8, self.graph.vertices) catch return;
        var queue = std.ArrayList([2]i32){};
        defer queue.deinit(arena_allocator);
        queue.ensureTotalCapacity(arena_allocator, self.graph.vertices) catch return;

        for (self.pairs.items) |pair| {
            const length = self.bfsShortestPathOpt(pair[0], pair[1], visited, &queue, arena_allocator);
            total_length += length;
        }

        // Сложение с переполнением как в C++ (&+=)
        self.result_val +%= @as(u32, @intCast(total_length));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};