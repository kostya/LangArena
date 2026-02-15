const std = @import("std");
const Helper = @import("helper.zig").Helper;
const Benchmark = @import("benchmark.zig").Benchmark;

pub const Graph = struct {
    allocator: std.mem.Allocator,
    vertices: usize,
    jumps: usize,
    jump_len: usize,
    adj: std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)),

    pub fn init(allocator: std.mem.Allocator, vertices: usize, jumps: usize, jump_len: usize) !*Graph {
        const self = try allocator.create(Graph);
        self.* = Graph{
            .allocator = allocator,
            .vertices = vertices,
            .jumps = jumps,
            .jump_len = jump_len,
            .adj = .{},
        };
        try self.adj.ensureTotalCapacity(allocator, vertices);
        for (0..vertices) |_| {
            self.adj.appendAssumeCapacity(.{});
        }
        return self;
    }

    pub fn deinit(self: *Graph) void {
        for (self.adj.items) |*neighbors| {
            neighbors.deinit(self.allocator);
        }
        self.adj.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn addEdge(self: *Graph, u: usize, v: usize) !void {
        try self.adj.items[u].append(self.allocator, v);
        try self.adj.items[v].append(self.allocator, u);
    }

    pub fn generateRandom(self: *Graph, helper: *Helper) !void {

        for (1..self.vertices) |i| {
            try self.addEdge(i, i - 1);
        }

        for (0..self.vertices) |v| {
            const num_jumps = @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(self.jumps)))));
            for (0..num_jumps) |_| {
                const offset = @as(i32, @intCast(helper.nextInt(@as(i32, @intCast(self.jump_len))))) - @as(i32, @intCast(self.jump_len / 2));
                const u = @as(i32, @intCast(v)) + offset;
                if (u >= 0 and u < self.vertices and u != v) {
                    try self.addEdge(v, @as(usize, @intCast(u)));
                }
            }
        }
    }
};

pub const GraphPathBFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: *Graph,
    result_val: u32,
    prepared: bool,

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
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathBFS) void {
        const allocator = self.allocator;
        if (self.prepared) {
            self.graph.deinit();
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
            const vertices_val = self.helper.config_i64("GraphPathBFS", "vertices");
            const jumps_val = self.helper.config_i64("GraphPathBFS", "jumps");
            const jump_len_val = self.helper.config_i64("GraphPathBFS", "jump_len");

            self.graph = Graph.init(allocator, @as(usize, @intCast(vertices_val)), @as(usize, @intCast(jumps_val)), @as(usize, @intCast(jump_len_val))) catch return;
            self.graph.generateRandom(self.helper) catch return;

            self.prepared = true;
        }
    }

    fn bfsShortestPath(self: *const GraphPathBFS, start: usize, target: usize, visited: []u8, queue: *std.ArrayList([2]i32), allocator: std.mem.Allocator) i32 {
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

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const visited = arena_allocator.alloc(u8, self.graph.vertices) catch return;
        var queue = std.ArrayList([2]i32){};
        defer queue.deinit(arena_allocator);

        const length = self.bfsShortestPath(0, self.graph.vertices - 1, visited, &queue, arena_allocator);
        if (length > 0) {
            self.result_val +%= @as(u32, @intCast(length));
        }
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

pub const GraphPathDFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: *Graph,
    result_val: u32,
    prepared: bool,

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
            .graph = undefined,
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDFS) void {
        const allocator = self.allocator;
        if (self.prepared) {
            self.graph.deinit();
        }
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GraphPathDFS");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (!self.prepared) {
            const vertices_val = self.helper.config_i64("GraphPathDFS", "vertices");
            const jumps_val = self.helper.config_i64("GraphPathDFS", "jumps");
            const jump_len_val = self.helper.config_i64("GraphPathDFS", "jump_len");

            self.graph = Graph.init(allocator, @as(usize, @intCast(vertices_val)), @as(usize, @intCast(jumps_val)), @as(usize, @intCast(jump_len_val))) catch return;
            self.graph.generateRandom(self.helper) catch return;

            self.prepared = true;
        }
    }

    fn dfsFindPath(self: *const GraphPathDFS, start: usize, target: usize, allocator: std.mem.Allocator) i32 {
        if (start == target) return 0;

        const vertices = self.graph.vertices;

        const visited = allocator.alloc(u8, vertices) catch return -1;
        defer allocator.free(visited);
        @memset(visited, 0);

        var stack = std.ArrayList([2]i32){};
        defer stack.deinit(allocator);

        const INF = std.math.maxInt(i32);
        var best_path: i32 = INF;

        stack.append(allocator, .{ @as(i32, @intCast(start)), 0 }) catch return -1;

        while (stack.items.len > 0) {
            const current = stack.pop().?; 
            const vertex = @as(usize, @intCast(current[0]));
            const distance = current[1];

            if (visited[vertex] == 1 or distance >= best_path) continue;
            visited[vertex] = 1;

            for (self.graph.adj.items[vertex].items) |neighbor| {
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

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const length = self.dfsFindPath(0, self.graph.vertices - 1, arena_allocator);
        if (length > 0) {
            self.result_val +%= @as(u32, @intCast(length));
        }
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

const PriorityQueue = struct {
    vertices: []i32,
    priorities: []i32,
    size: usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, capacity: usize) !PriorityQueue {
        return PriorityQueue{
            .vertices = try allocator.alloc(i32, capacity),
            .priorities = try allocator.alloc(i32, capacity),
            .size = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *PriorityQueue) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.priorities);
    }

    fn push(self: *PriorityQueue, vertex: i32, priority: i32, _: std.mem.Allocator) !void {
        if (self.size >= self.vertices.len) {
            const new_capacity = self.vertices.len * 2;
            self.vertices = try self.allocator.realloc(self.vertices, new_capacity);
            self.priorities = try self.allocator.realloc(self.priorities, new_capacity);
        }

        var i = self.size;
        self.size += 1;
        self.vertices[i] = vertex;
        self.priorities[i] = priority;

        while (i > 0) {
            const parent = (i - 1) / 2;
            if (self.priorities[parent] <= self.priorities[i]) break;
            std.mem.swap(i32, &self.vertices[i], &self.vertices[parent]);
            std.mem.swap(i32, &self.priorities[i], &self.priorities[parent]);
            i = parent;
        }
    }

    fn pop(self: *PriorityQueue) ?i32 {
        if (self.size == 0) return null;

        const result = self.vertices[0];
        self.size -= 1;

        if (self.size > 0) {
            self.vertices[0] = self.vertices[self.size];
            self.priorities[0] = self.priorities[self.size];

            var i: usize = 0;
            while (true) {
                const left = 2 * i + 1;
                const right = 2 * i + 2;
                var smallest = i;

                if (left < self.size and self.priorities[left] < self.priorities[smallest]) {
                    smallest = left;
                }
                if (right < self.size and self.priorities[right] < self.priorities[smallest]) {
                    smallest = right;
                }
                if (smallest == i) break;

                std.mem.swap(i32, &self.vertices[i], &self.vertices[smallest]);
                std.mem.swap(i32, &self.priorities[i], &self.priorities[smallest]);
                i = smallest;
            }
        }

        return result;
    }
};

pub const GraphPathAStar = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: *Graph,
    result_val: u32,
    prepared: bool,

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathAStar {
        const self = try allocator.create(GraphPathAStar);
        errdefer allocator.destroy(self);

        self.* = GraphPathAStar{
            .allocator = allocator,
            .helper = helper,
            .graph = undefined,
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathAStar) void {
        const allocator = self.allocator;
        if (self.prepared) {
            self.graph.deinit();
        }
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathAStar) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GraphPathAStar");
    }

    fn heuristic(v: usize, target: usize) i32 {
        return @as(i32, @intCast(target)) - @as(i32, @intCast(v));
    }

    fn aStarShortestPath(self: *const GraphPathAStar, start: usize, target: usize, allocator: std.mem.Allocator) !i32 {
        if (start == target) return 0;

        const vertices = self.graph.vertices;

        const g_score = try allocator.alloc(i32, vertices);
        defer allocator.free(g_score);
        @memset(g_score, std.math.maxInt(i32));
        g_score[start] = 0;

        const closed = try allocator.alloc(u8, vertices);
        defer allocator.free(closed);
        @memset(closed, 0);

        var open_set = try PriorityQueue.init(allocator, vertices);
        defer open_set.deinit();

        const in_open_set = try allocator.alloc(u8, vertices);
        defer allocator.free(in_open_set);
        @memset(in_open_set, 0);

        try open_set.push(@as(i32, @intCast(start)), heuristic(start, target), allocator);
        in_open_set[start] = 1;

        while (open_set.pop()) |current| {
            const cur = @as(usize, @intCast(current));
            in_open_set[cur] = 0;

            if (cur == target) {
                return g_score[cur];
            }

            closed[cur] = 1;

            for (self.graph.adj.items[cur].items) |neighbor| {
                if (closed[neighbor] == 1) continue;

                const tentative_g = g_score[cur] + 1;

                if (tentative_g < g_score[neighbor]) {
                    g_score[neighbor] = tentative_g;
                    const f = tentative_g + heuristic(neighbor, target);

                    if (in_open_set[neighbor] == 0) {
                        try open_set.push(@as(i32, @intCast(neighbor)), f, allocator);
                        in_open_set[neighbor] = 1;
                    }
                }
            }
        }

        return -1;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathAStar = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (!self.prepared) {
            const vertices_val = self.helper.config_i64("GraphPathAStar", "vertices");
            const jumps_val = self.helper.config_i64("GraphPathAStar", "jumps");
            const jump_len_val = self.helper.config_i64("GraphPathAStar", "jump_len");

            self.graph = Graph.init(allocator, @as(usize, @intCast(vertices_val)), @as(usize, @intCast(jumps_val)), @as(usize, @intCast(jump_len_val))) catch return;
            self.graph.generateRandom(self.helper) catch return;

            self.prepared = true;
        }
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GraphPathAStar = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const length = self.aStarShortestPath(0, self.graph.vertices - 1, arena_allocator) catch -1;
        if (length > 0) {
            self.result_val +%= @as(u32, @intCast(length));
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathAStar = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathAStar = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};