const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const GraphPathDFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    graph: std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)),
    pairs: std.ArrayListUnmanaged(struct { usize, usize }),
    pairs_val: i64,
    vertices_val: i64,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .prepare = prepareImpl,
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
            .pairs_val = 0,
            .vertices_val = 0,
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *GraphPathDFS) void {
        for (self.graph.items) |*neighbors| {
            neighbors.deinit(self.allocator);
        }
        self.graph.deinit(self.allocator);
        self.pairs.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *GraphPathDFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));

        if (self.pairs_val == 0) {
            self.pairs_val = self.helper.config_i64("GraphPathDFS", "pairs");
            self.vertices_val = self.helper.config_i64("GraphPathDFS", "vertices");

            const vertices = @as(usize, @intCast(self.vertices_val));
            const comps = @max(10, vertices / 10000);

            // Очищаем старый граф
            for (self.graph.items) |*neighbors| {
                neighbors.deinit(self.allocator);
            }
            self.graph.clearAndFree(self.allocator);
            self.pairs.clearAndFree(self.allocator);

            // Инициализируем списки смежности
            self.graph.ensureTotalCapacity(self.allocator, vertices) catch return;
            for (0..vertices) |_| {
                self.graph.appendAssumeCapacity(.{});
            }

            const component_size = vertices / comps;

            // Генерируем граф (такой же как в BFS)
            for (0..comps) |c| {
                const start_idx = c * component_size;
                const end_idx = if (c == comps - 1) vertices else (c + 1) * component_size;

                var i = start_idx + 1;
                while (i < end_idx) : (i += 1) {
                    const parent = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(i - start_idx)))));
                    self.graph.items[i].append(self.allocator, parent) catch return;
                    self.graph.items[parent].append(self.allocator, i) catch return;
                }

                const extra_edges = component_size * 2;
                for (0..extra_edges) |_| {
                    const u = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    const v = start_idx + @as(usize, @intCast(self.helper.nextInt(@as(i32, @intCast(end_idx - start_idx)))));
                    if (u != v) {
                        self.graph.items[u].append(self.allocator, v) catch return;
                        self.graph.items[v].append(self.allocator, u) catch return;
                    }
                }
            }

            // Генерируем пары (такие же как в BFS)
            const pairs_count = @as(usize, @intCast(self.pairs_val));
            self.pairs.ensureTotalCapacity(self.allocator, pairs_count) catch return;

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
        }
    }

    // DFS для поиска пути
    fn dfsFindPath(self: *GraphPathDFS, start: usize, target: usize) i32 {
        if (start == target) return 0;

        const vertices = self.graph.items.len;
        var visited = std.ArrayList(bool).init(self.allocator);
        defer visited.deinit();

        visited.resize(vertices, false) catch return -1;

        var stack = std.ArrayList(struct { usize, i32 }).init(self.allocator);
        defer stack.deinit();

        const INF = std.math.maxInt(i32);
        var best_path: i32 = INF;

        stack.append(.{ start, 0 }) catch return -1;

        while (stack.items.len > 0) {
            const current = stack.pop() orelse break;
            const vertex = current[0];
            const distance = current[1];

            if (visited.items[vertex] or distance >= best_path) continue;
            visited.items[vertex] = true;

            for (self.graph.items[vertex].items) |neighbor| {
                if (neighbor == target) {
                    if (distance + 1 < best_path) {
                        best_path = distance + 1;
                    }
                } else if (!visited.items[neighbor]) {
                    stack.append(.{ neighbor, distance + 1 }) catch return -1;
                }
            }
        }

        return if (best_path == INF) -1 else best_path;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *GraphPathDFS = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        var total_length: i64 = 0;

        for (self.pairs.items) |pair| {
            const length = self.dfsFindPath(pair[0], pair[1]);
            if (length >= 0) {
                total_length += length;
            }
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