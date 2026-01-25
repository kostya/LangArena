// src/graph_path_dfs.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const GraphPathBenchmark = @import("graph_path_base.zig").GraphPathBenchmark;

pub const GraphPathDFS = struct {
    base: GraphPathBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathDFS {
        const self = try allocator.create(GraphPathDFS);
        errdefer allocator.destroy(self);

        self.* = GraphPathDFS{
            .base = try GraphPathBenchmark.init(allocator, helper, "GraphPathDFS"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDFS) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDFS) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    fn dfsFindPath(self: *GraphPathDFS, start: usize, target: usize, visited: []bool, stack: *std.ArrayList(struct { usize, i32 })) i32 {
        if (start == target) return 0;

        @memset(visited, false);
        stack.clearRetainingCapacity();

        const INF = std.math.maxInt(i32);
        var best_path: i32 = INF;

        stack.appendAssumeCapacity(.{ start, 0 });

        // В dfsFindPath:
        while (stack.items.len > 0) {
            const current = stack.pop(); // Это T? (optional)

            // Разворачиваем optional
            const vertex = current.?[0];
            const distance = current.?[1];

            if (visited[vertex] or distance >= best_path) continue;
            visited[vertex] = true;

            for (self.base.graph.adj.items[vertex].items) |neighbor| {
                if (neighbor == target) {
                    if (distance + 1 < best_path) {
                        best_path = distance + 1;
                    }
                } else if (!visited[neighbor]) {
                    stack.appendAssumeCapacity(.{ neighbor, distance + 1 });
                }
            }
        }

        return if (best_path == INF) -1 else best_path;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));

        // Генерируем граф и пары
        self.base.graph.generateRandom(self.base.helper) catch return;
        self.base.generatePairs() catch return;
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Предварительно аллоцировать
        const visited = arena_allocator.alloc(bool, self.base.graph.vertices) catch return;
        var stack: std.ArrayList(struct { usize, i32 }) = .empty;
        defer stack.deinit(arena_allocator);
        stack.ensureTotalCapacity(arena_allocator, self.base.graph.vertices) catch return;

        self.base.result_val = 0;

        for (self.base.pairs.items) |pair| {
            const length = self.dfsFindPath(pair[0], pair[1], visited, &stack);
            self.base.result_val += length;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        return @as(u32, @bitCast(@as(i32, @truncate(self.base.result_val))));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
