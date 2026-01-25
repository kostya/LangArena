// src/graph_path_dijkstra.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const GraphPathBenchmark = @import("graph_path_base.zig").GraphPathBenchmark;

pub const GraphPathDijkstra = struct {
    base: GraphPathBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathDijkstra {
        const self = try allocator.create(GraphPathDijkstra);
        errdefer allocator.destroy(self);

        self.* = GraphPathDijkstra{
            .base = try GraphPathBenchmark.init(allocator, helper, "GraphPathDijkstra"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDijkstra) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDijkstra) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    fn dijkstraShortestPath(self: *GraphPathDijkstra, start: usize, target: usize, dist: []i32, visited: []bool) i32 {
        if (start == target) return 0;

        const INF = std.math.maxInt(i32) / 2;

        // Инициализация
        @memset(dist, INF);
        @memset(visited, false);
        dist[start] = 0;

        for (0..self.base.graph.vertices) |_| {
            var u: i32 = -1;
            var min_dist: i32 = INF;

            // Находим непосещенную вершину с минимальным расстоянием
            for (0..self.base.graph.vertices) |v| {
                if (!visited[v] and dist[v] < min_dist) {
                    min_dist = dist[v];
                    u = @as(i32, @intCast(v));
                }
            }

            // Если вершина не найдена или достигли цели
            if (u == -1 or min_dist == INF or u == @as(i32, @intCast(target))) {
                return if (u == @as(i32, @intCast(target))) min_dist else -1;
            }

            visited[@as(usize, @intCast(u))] = true;

            // Обновляем расстояния до соседей
            for (self.base.graph.adj.items[@as(usize, @intCast(u))].items) |v| {
                const new_dist = dist[@as(usize, @intCast(u))] + 1;
                if (new_dist < dist[v]) {
                    dist[v] = new_dist;
                }
            }
        }

        return -1;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));

        // Генерируем граф и пары
        self.base.graph.generateRandom(self.base.helper) catch return;
        self.base.generatePairs() catch return;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Предварительно аллоцировать
        const dist = arena_allocator.alloc(i32, self.base.graph.vertices) catch return;
        const visited = arena_allocator.alloc(bool, self.base.graph.vertices) catch return;

        self.base.result_val = 0;

        for (self.base.pairs.items) |pair| {
            const length = self.dijkstraShortestPath(pair[0], pair[1], dist, visited);
            self.base.result_val += length;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        return @as(u32, @bitCast(@as(i32, @truncate(self.base.result_val))));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
