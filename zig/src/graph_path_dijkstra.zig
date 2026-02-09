const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GraphPathDijkstra = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: std.ArrayList(std.ArrayList(usize)), 
    pairs: std.ArrayList([2]usize), 
    result_val: u32,
    prepared: bool, 

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*GraphPathDijkstra {
        const self = try allocator.create(GraphPathDijkstra);
        errdefer allocator.destroy(self);

        self.* = GraphPathDijkstra{
            .allocator = allocator,
            .helper = helper,
            .graph = .{},
            .pairs = .{},
            .result_val = 0,
            .prepared = false,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDijkstra) void {
        const allocator = self.allocator;

        for (self.graph.items) |*neighbors| {
            neighbors.deinit(allocator);
        }
        self.graph.deinit(allocator);
        self.pairs.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDijkstra) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "GraphPathDijkstra");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (!self.prepared) {
            const pairs_val = self.helper.config_i64("GraphPathDijkstra", "pairs");
            const vertices_val = self.helper.config_i64("GraphPathDijkstra", "vertices");

            const vertices = @as(usize, @intCast(vertices_val));
            const comps = @max(@as(usize, 10), vertices / 10000);

            for (self.graph.items) |*neighbors| {
                neighbors.deinit(allocator);
            }
            self.graph.clearAndFree(allocator);
            self.pairs.clearAndFree(allocator);
            self.result_val = 0;

            self.graph.ensureTotalCapacity(allocator, vertices) catch return;
            for (0..vertices) |_| {
                self.graph.append(allocator, .{}) catch return;
            }

            const component_size = vertices / comps;

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

    fn dijkstraShortestPath(self: *const GraphPathDijkstra, start: usize, target: usize, allocator: std.mem.Allocator) i32 {
        if (start == target) return 0;

        const vertices = self.graph.items.len;
        const INF = std.math.maxInt(i32) / 2;

        const dist = allocator.alloc(i32, vertices) catch return -1;
        defer allocator.free(dist);
        @memset(dist, INF);

        const visited = allocator.alloc(u8, vertices) catch return -1;
        defer allocator.free(visited);
        @memset(visited, 0);

        dist[start] = 0;

        for (0..vertices) |_| {
            var u: i32 = -1;
            var min_dist: i32 = INF;

            for (0..vertices) |v| {
                if (visited[v] == 0 and dist[v] < min_dist) {
                    min_dist = dist[v];
                    u = @as(i32, @intCast(v));
                }
            }

            if (u == -1 or min_dist == INF or u == @as(i32, @intCast(target))) {
                return if (u == @as(i32, @intCast(target))) min_dist else -1;
            }

            visited[@as(usize, @intCast(u))] = 1;

            for (self.graph.items[@as(usize, @intCast(u))].items) |v| {
                const new_dist = dist[@as(usize, @intCast(u))] + 1;
                if (new_dist < dist[v]) {
                    dist[v] = new_dist;
                }
            }
        }

        return -1;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        var total_length: i32 = 0;

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        for (self.pairs.items) |pair| {
            const length = self.dijkstraShortestPath(pair[0], pair[1], arena_allocator);
            total_length += length;
        }

        self.result_val +%= @as(u32, @intCast(total_length));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *GraphPathDijkstra = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};