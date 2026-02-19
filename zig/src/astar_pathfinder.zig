const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const MazeGenerator = @import("maze_generator.zig").MazeGenerator;

pub const AStarPathfinder = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    start_x: i32,
    start_y: i32,
    goal_x: i32,
    goal_y: i32,
    result_val: u32,
    maze_grid: ?[]const []const bool,

    g_scores_cache: ?[]i32 = null,
    came_from_cache: ?[]i32 = null,

    const Node = struct {
        x: i32,
        y: i32,
        f_score: i32,

        pub fn init(x: i32, y: i32, f_score: i32) Node {
            return .{ .x = x, .y = y, .f_score = f_score };
        }

        pub fn compare(context: void, a: Node, b: Node) std.math.Order {
            _ = context;

            if (a.f_score < b.f_score) return .lt;
            if (a.f_score > b.f_score) return .gt;
            if (a.y < b.y) return .lt;
            if (a.y > b.y) return .gt;
            if (a.x < b.x) return .lt;
            if (a.x > b.x) return .gt;
            return .eq;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    const NodeQueue = std.PriorityQueue(Node, void, Node.compare);

    fn packCoords(self: *AStarPathfinder, x: i32, y: i32) i32 {
        return y * self.width + x;
    }

    fn unpackCoords(self: *AStarPathfinder, packed1: i32) struct { x: i32, y: i32 } {
        return .{
            .x = @mod(packed1, self.width),
            .y = @divFloor(packed1, self.width),
        };
    }

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*AStarPathfinder {
        const w = helper.config_i64("AStarPathfinder", "w");
        const h = helper.config_i64("AStarPathfinder", "h");
        const width = @as(i32, @intCast(w));
        const height = @as(i32, @intCast(h));
        const self = try allocator.create(AStarPathfinder);
        self.* = AStarPathfinder{
            .allocator = allocator,
            .helper = helper,
            .width = width,
            .height = height,
            .start_x = 1,
            .start_y = 1,
            .goal_x = width - 2,
            .goal_y = height - 2,
            .result_val = 0,
            .maze_grid = null,
        };

        const size = @as(usize, @intCast(width * height));
        self.g_scores_cache = try allocator.alloc(i32, size);
        self.came_from_cache = try allocator.alloc(i32, size);

        return self;
    }

    pub fn deinit(self: *AStarPathfinder) void {
        if (self.maze_grid) |grid| {
            for (grid) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(grid);
        }

        if (self.g_scores_cache) |g_scores| {
            self.allocator.free(g_scores);
        }

        if (self.came_from_cache) |came_from| {
            self.allocator.free(came_from);
        }

        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *AStarPathfinder) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "AStarPathfinder");
    }

    fn distance(ax: i32, ay: i32, bx: i32, by: i32) i32 {
        const dx = if (ax > bx) ax - bx else bx - ax;
        const dy = if (ay > by) ay - by else by - ay;
        return dx + dy;
    }

    fn ensureMazeGrid(self: *AStarPathfinder) ![]const []const bool {
        if (self.maze_grid) |grid| {
            return grid;
        }
        const grid = try MazeGenerator.generateWalkableMaze(self.allocator, self.helper, self.width, self.height);
        self.maze_grid = grid;
        return grid;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        _ = self.ensureMazeGrid() catch return;
    }

    fn findPath(self: *AStarPathfinder, maze_grid: []const []const bool) struct { path_length: u32, nodes_explored: u32, found: bool } {
        const width = self.width;
        const height = self.height;
        const start_x = self.start_x;
        const start_y = self.start_y;
        const goal_x = self.goal_x;
        const goal_y = self.goal_y;

        const g_scores = self.g_scores_cache.?;
        const came_from = self.came_from_cache.?;

        @memset(g_scores, std.math.maxInt(i32));
        @memset(came_from, -1);

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var open_set = NodeQueue.init(allocator, {});
        defer open_set.deinit();

        const start_idx = self.packCoords(start_x, start_y);
        g_scores[@as(usize, @intCast(start_idx))] = 0;
        const start_f = distance(start_x, start_y, goal_x, goal_y);
        open_set.add(Node.init(start_x, start_y, start_f)) catch return .{ .path_length = 0, .nodes_explored = 0, .found = false };

        const directions = [_][2]i32{ .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 } };
        var nodes_explored: u32 = 0;

        while (open_set.count() > 0) {
            const current = open_set.remove();
            nodes_explored += 1;

            if (current.x == goal_x and current.y == goal_y) {
                var path_length: u32 = 1;
                var x = current.x;
                var y = current.y;

                while (x != start_x or y != start_y) {
                    const idx = self.packCoords(x, y);
                    const packed1 = came_from[@as(usize, @intCast(idx))];
                    if (packed1 == -1) break;

                    const coords = self.unpackCoords(packed1);
                    x = coords.x;
                    y = coords.y;
                    path_length += 1;
                }

                return .{ .path_length = path_length, .nodes_explored = nodes_explored, .found = true };
            }

            const current_idx = self.packCoords(current.x, current.y);
            const current_g = g_scores[@as(usize, @intCast(current_idx))];

            for (directions) |dir| {
                const nx = current.x + dir[0];
                const ny = current.y + dir[1];

                if (nx < 0 or ny < 0 or nx >= width or ny >= height) continue;
                if (!maze_grid[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))]) continue;

                const tentative_g = current_g + 1000;
                const neighbor_idx = self.packCoords(nx, ny);

                if (tentative_g < g_scores[@as(usize, @intCast(neighbor_idx))]) {
                    came_from[@as(usize, @intCast(neighbor_idx))] = current_idx;
                    g_scores[@as(usize, @intCast(neighbor_idx))] = tentative_g;

                    const f_score = tentative_g + distance(nx, ny, goal_x, goal_y);
                    open_set.add(Node.init(nx, ny, f_score)) catch return .{ .path_length = 0, .nodes_explored = nodes_explored, .found = false };
                }
            }
        }

        return .{ .path_length = 0, .nodes_explored = nodes_explored, .found = false };
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        const maze_grid = self.ensureMazeGrid() catch return;
        const result = self.findPath(maze_grid);

        var local_result: u32 = 0;

        local_result = result.path_length;

        local_result = (local_result << 5) + result.nodes_explored;

        self.result_val +%= local_result;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
