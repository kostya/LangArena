const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const Graph = struct {
    allocator: std.mem.Allocator,
    vertices: usize,
    components: usize,
    adj: std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)),

    pub fn init(allocator: std.mem.Allocator, vertices: usize, components: usize) !Graph {
        var self = Graph{
            .allocator = allocator,
            .vertices = vertices,
            .components = components,
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
    }

    pub fn addEdge(self: *Graph, u: usize, v: usize) !void {
        try self.adj.items[u].append(self.allocator, v);
        try self.adj.items[v].append(self.allocator, u);
    }

    pub fn generateRandom(self: *Graph, helper: *Helper) !void {
        const component_size = self.vertices / self.components;
        for (0..self.components) |c| {
            const start_idx = c * component_size;
            const end_idx = if (c == self.components - 1) self.vertices else (c + 1) * component_size;
            var i = start_idx + 1;
            while (i < end_idx) : (i += 1) {
                const parent = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(i - start_idx)))));
                try self.addEdge(i, parent);
            }
            const extra_edges = component_size * 2;
            for (0..extra_edges) |_| {
                const u = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                const v = start_idx + @as(usize, @intCast(helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                if (u != v) {
                    try self.addEdge(u, v);
                }
            }
        }
    }
};

pub const GraphPathBenchmark = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: *Graph,
    pairs: std.ArrayListUnmanaged(struct { usize, usize }),
    n_pairs: i64,
    result_val: u32,

    pub fn init(allocator: std.mem.Allocator, helper: *Helper, bench_name: []const u8) !GraphPathBenchmark {
        const n_pairs = helper.configVal(bench_name, "pairs") orelse 0;
        const vertices = helper.configVal(bench_name, "vertices") orelse @as(i64, n_pairs * 10);
        const comps = @max(10, vertices / 10000);
        const graph = try allocator.create(Graph);
        errdefer allocator.destroy(graph);
        graph.* = try Graph.init(allocator, @as(usize, @intCast(vertices)), @as(usize, @intCast(comps)));
        return GraphPathBenchmark{
            .allocator = allocator,
            .helper = helper,
            .graph = graph,
            .pairs = .{},
            .n_pairs = n_pairs,
            .result_val = 0,
        };
    }

    pub fn deinit(self: *GraphPathBenchmark) void {
        self.pairs.deinit(self.allocator);
        self.graph.deinit();
        self.allocator.destroy(self.graph);
    }

    pub fn generatePairs(self: *GraphPathBenchmark) !void {
        const component_size = self.graph.vertices / 10;
        try self.pairs.ensureTotalCapacity(self.allocator, @as(usize, @intCast(self.n_pairs)));
        for (0..@as(usize, @intCast(self.n_pairs))) |_| {
            var start: usize = undefined;
            var end: usize = undefined;
            if (self.helper.nextInt(100) < 70) {
                const component = @as(usize, @intCast(self.helper.nextInt(10)));
                start = component * component_size + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size)))));
                while (true) {
                    end = component * component_size + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size)))));
                    if (end != start) break;
                }
            } else {
                const c1 = @as(usize, @intCast(self.helper.nextInt(10)));
                var c2: usize = undefined;
                while (true) {
                    c2 = @as(usize, @intCast(self.helper.nextInt(10)));
                    if (c2 != c1) break;
                }
                start = c1 * component_size + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size)))));
                end = c2 * component_size + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(component_size)))));
            }
            self.pairs.appendAssumeCapacity(.{ start, end });
        }
    }
};