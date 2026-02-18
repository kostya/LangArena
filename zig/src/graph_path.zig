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

    fn bfsShortestPath(self: *const GraphPathBFS, start: usize, target: usize, visited: []u8, queue: *std.ArrayList([2]i32), queue_allocator: std.mem.Allocator) i32 {
        if (start == target) return 0;

        @memset(visited, 0);
        queue.clearRetainingCapacity();

        visited[start] = 1;
        queue.append(queue_allocator, .{ @as(i32, @intCast(start)), 0 }) catch return -1;

        var front: usize = 0;
        while (front < queue.items.len) {
            const current = queue.items[front];
            front += 1;

            for (self.graph.adj.items[@as(usize, @intCast(current[0]))].items) |neighbor| {
                if (neighbor == target) return current[1] + 1;

                if (visited[neighbor] == 0) {
                    visited[neighbor] = 1;
                    queue.append(queue_allocator, .{ @as(i32, @intCast(neighbor)), current[1] + 1 }) catch return -1;
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

        var queue: std.ArrayList([2]i32) = .empty;
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

        var stack: std.ArrayList([2]i32) = .empty;
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

const Node = struct {
    vertex: i32,
    f_score: i32,
};

const PriorityQueue = struct {
    nodes: std.ArrayListUnmanaged(Node),

    fn init() PriorityQueue {
        return .{ .nodes = .{} };
    }

    fn deinit(self: *PriorityQueue, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }

    fn push(self: *PriorityQueue, allocator: std.mem.Allocator, vertex: i32, f_score: i32) !void {
        try self.nodes.append(allocator, .{ .vertex = vertex, .f_score = f_score });
        heapifyUp(self.nodes.items);
    }

    fn pop(self: *PriorityQueue) ?Node {
        if (self.nodes.items.len == 0) return null;

        const node = self.nodes.items[0];
        self.nodes.items[0] = self.nodes.items[self.nodes.items.len - 1];
        _ = self.nodes.pop();

        if (self.nodes.items.len > 0) {
            heapifyDown(self.nodes.items);
        }
        return node;
    }

    fn empty(self: *const PriorityQueue) bool {
        return self.nodes.items.len == 0;
    }

    fn heapifyUp(items: []Node) void {
        var i: usize = items.len - 1;
        while (i > 0) {
            const parent = (i - 1) / 2;
            if (items[parent].f_score <= items[i].f_score) break;
            std.mem.swap(Node, &items[i], &items[parent]);
            i = parent;
        }
    }

    fn heapifyDown(items: []Node) void {
        var i: usize = 0;
        const n = items.len;
        while (true) {
            const left = 2 * i + 1;
            const right = 2 * i + 2;
            var smallest = i;

            if (left < n and items[left].f_score < items[smallest].f_score) {
                smallest = left;
            }
            if (right < n and items[right].f_score < items[smallest].f_score) {
                smallest = right;
            }
            if (smallest == i) break;

            std.mem.swap(Node, &items[i], &items[smallest]);
            i = smallest;
        }
    }
};

fn heuristic(v: usize, target: usize) i32 {
    return @as(i32, @intCast(target)) - @as(i32, @intCast(v));
}

fn aStarShortestPath(graph: *const Graph, start: usize, target: usize, allocator: std.mem.Allocator) i32 {
    if (start == target) return 0;

    const vertices = graph.vertices;
    const INF = std.math.maxInt(i32);

    const g_score = allocator.alloc(i32, vertices) catch return -1;
    defer allocator.free(g_score);
    @memset(g_score, INF);
    g_score[start] = 0;

    const f_score = allocator.alloc(i32, vertices) catch return -1;
    defer allocator.free(f_score);
    @memset(f_score, INF);
    f_score[start] = heuristic(start, target);

    const in_open_set = allocator.alloc(u8, vertices) catch return -1;
    defer allocator.free(in_open_set);
    @memset(in_open_set, 0);

    const closed = allocator.alloc(u8, vertices) catch return -1;
    defer allocator.free(closed);
    @memset(closed, 0);

    var open_set = PriorityQueue.init();
    defer open_set.deinit(allocator);

    open_set.push(allocator, @intCast(start), f_score[start]) catch return -1;
    in_open_set[start] = 1;

    while (!open_set.empty()) {
        const current = open_set.pop().?;
        const cur = @as(usize, @intCast(current.vertex));

        if (closed[cur] == 1) continue;
        closed[cur] = 1;
        in_open_set[cur] = 0;

        if (cur == target) {
            return g_score[cur];
        }

        for (graph.adj.items[cur].items) |neighbor| {
            if (closed[neighbor] == 1) continue;

            const tentative_g = g_score[cur] + 1;

            if (tentative_g < g_score[neighbor]) {
                g_score[neighbor] = tentative_g;
                f_score[neighbor] = tentative_g + heuristic(neighbor, target);

                if (in_open_set[neighbor] == 0) {
                    open_set.push(allocator, @intCast(neighbor), f_score[neighbor]) catch return -1;
                    in_open_set[neighbor] = 1;
                }
            }
        }
    }

    return -1;
}

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

        const length = aStarShortestPath(self.graph, 0, self.graph.vertices - 1, arena_allocator);
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