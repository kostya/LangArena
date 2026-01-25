// src/graph_path_bfs.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const GraphPathBenchmark = @import("graph_path_base.zig").GraphPathBenchmark;

pub const GraphPathBFS = struct {
    base: GraphPathBenchmark,
    allocator: std.mem.Allocator,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathBFS {
        const self = try allocator.create(GraphPathBFS);
        errdefer allocator.destroy(self);

        self.* = GraphPathBFS{
            .base = try GraphPathBenchmark.init(allocator, helper, "GraphPathBFS"),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathBFS) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathBFS) Benchmark {
        return Benchmark.init(self, &vtable, self.base.helper);
    }

    // 1. Предварительно аллоцировать массивы
    fn bfsShortestPathOpt(self: *GraphPathBFS, start: usize, target: usize, visited: []bool, queue: *std.ArrayList(struct { usize, i32 })) i32 {
        if (start == target) return 0;

        @memset(visited, false);
        queue.clearRetainingCapacity();

        visited[start] = true;
        queue.appendAssumeCapacity(.{ start, 0 });

        var front: usize = 0;
        while (front < queue.items.len) {
            const current = queue.items[front];
            front += 1;

            for (self.base.graph.adj.items[current[0]].items) |neighbor| {
                if (neighbor == target) return current[1] + 1;

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue.appendAssumeCapacity(.{ neighbor, current[1] + 1 });
                }
            }
        }

        return -1;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));

        // Генерируем граф и пары
        self.base.graph.generateRandom(self.base.helper) catch return;
        self.base.generatePairs() catch return;
    }

    // 2. В runImpl переиспользовать память
    fn runImpl(ptr: *anyopaque) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Предварительно аллоцировать
        const visited = arena_allocator.alloc(bool, self.base.graph.vertices) catch return;
        var queue: std.ArrayList(struct { usize, i32 }) = .empty;
        defer queue.deinit(arena_allocator);
        queue.ensureTotalCapacity(arena_allocator, self.base.graph.vertices) catch return;

        self.base.result_val = 0;

        for (self.base.pairs.items) |pair| {
            const length = self.bfsShortestPathOpt(pair[0], pair[1], visited, &queue);
            self.base.result_val += length;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        return @as(u32, @bitCast(@as(i32, @truncate(self.base.result_val))));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathBFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
