// src/astar_pathfinder.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const MazeGenerator = @import("maze_generator.zig").MazeGenerator;

pub const AStarPathfinder = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: u32,
    height: u32,
    start_x: u32,
    start_y: u32,
    goal_x: u32,
    goal_y: u32,
    result_val: u64,
    maze_grid: ?[]bool, // Для кэширования лабиринта

    const Heuristic = enum { manhattan, euclidean, chebyshev };
    const Move = enum { cardinal, diagonal };

    const Node = struct {
        x: u32,
        y: u32,
        f_score: u32,

        pub fn init(x: u32, y: u32, f_score: u32) Node {
            return .{ .x = x, .y = y, .f_score = f_score };
        }

        pub fn lessThan(context: void, a: Node, b: Node) bool {
            _ = context;
            if (a.f_score != b.f_score) return a.f_score < b.f_score;
            if (a.y != b.y) return a.y < b.y;
            return a.x < b.x;
        }
    };

    const PathResult = struct {
        found: bool,
        length: u32,
        nodes_explored: u32,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .prepare = prepareImpl,
        .deinit = deinitImpl,
    };

    const BinaryHeap = struct {
        items: std.ArrayList(Node),
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator) BinaryHeap {
            return .{
                .items = std.ArrayList(Node).empty,
                .allocator = allocator,
            };
        }

        fn deinit(self: *BinaryHeap) void {
            self.items.deinit(self.allocator);
        }

        fn push(self: *BinaryHeap, node: Node) !void {
            try self.items.append(self.allocator, node);
            var index = self.items.items.len - 1;

            while (index > 0) {
                const parent = (index - 1) / 2;
                if (Node.lessThan({}, self.items.items[index], self.items.items[parent])) {
                    std.mem.swap(Node, &self.items.items[index], &self.items.items[parent]);
                    index = parent;
                } else {
                    break;
                }
            }
        }

        fn pop(self: *BinaryHeap) ?Node {
            if (self.items.items.len == 0) return null;

            const result = self.items.items[0];

            if (self.items.items.len == 1) {
                _ = self.items.pop();
                return result;
            }

            const last = self.items.items[self.items.items.len - 1];
            _ = self.items.pop();

            self.items.items[0] = last;
            var index: usize = 0;
            const size = self.items.items.len;

            while (true) {
                var smallest = index;
                const left = index * 2 + 1;
                const right = left + 1;

                if (left < size and Node.lessThan({}, self.items.items[left], self.items.items[smallest])) {
                    smallest = left;
                }

                if (right < size and Node.lessThan({}, self.items.items[right], self.items.items[smallest])) {
                    smallest = right;
                }

                if (smallest == index) break;

                std.mem.swap(Node, &self.items.items[index], &self.items.items[smallest]);
                index = smallest;
            }

            return result;
        }

        fn isEmpty(self: *const BinaryHeap) bool {
            return self.items.items.len == 0;
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*AStarPathfinder {
        const maze_size = helper.getInputInt("AStarPathfinder");
        const size: u32 = @intCast(if (maze_size > 0) maze_size else 100);

        const self = try allocator.create(AStarPathfinder);
        self.* = AStarPathfinder{
            .allocator = allocator,
            .helper = helper,
            .width = size,
            .height = size,
            .start_x = 1,
            .start_y = 1,
            .goal_x = if (size >= 2) size - 2 else 0,
            .goal_y = if (size >= 2) size - 2 else 0,
            .result_val = 0,
            .maze_grid = null,
        };
        return self;
    }

    pub fn deinit(self: *AStarPathfinder) void {
        // Освобождаем лабиринт если есть
        if (self.maze_grid) |grid| {
            self.allocator.free(grid);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *AStarPathfinder) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn ensureMazeGrid(self: *AStarPathfinder) ![]bool {
        // Если лабиринт уже сгенерирован, возвращаем его
        if (self.maze_grid) |grid| {
            return grid;
        }

        // Генерируем новый лабиринт
        const grid = try MazeGenerator.generateWalkableMaze(self.allocator, self.width, self.height, self.helper);

        self.maze_grid = grid;
        return grid;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        // Генерируем лабиринт один раз как в C++
        _ = self.ensureMazeGrid() catch return;
    }

    fn heuristicDistance(heuristic: Heuristic, ax: u32, ay: u32, bx: u32, by: u32) u32 {
        const dx = @abs(@as(i32, @intCast(ax)) - @as(i32, @intCast(bx)));
        const dy = @abs(@as(i32, @intCast(ay)) - @as(i32, @intCast(by)));

        return switch (heuristic) {
            .manhattan => @as(u32, @intCast(dx + dy)) * 1000,
            .euclidean => {
                const dx_f = @as(f64, @floatFromInt(dx));
                const dy_f = @as(f64, @floatFromInt(dy));
                const distance = @sqrt(dx_f * dx_f + dy_f * dy_f);
                return @as(u32, @intFromFloat(distance * 1000.0));
            },
            .chebyshev => @as(u32, @intCast(@max(dx, dy))) * 1000,
        };
    }

    fn findPath(
        self: *AStarPathfinder,
        maze_grid: []const bool,
        heuristic: Heuristic,
        move_type: Move,
    ) !PathResult {
        const width = self.width;
        const height = self.height;
        const start_x = self.start_x;
        const start_y = self.start_y;
        const goal_x = self.goal_x;
        const goal_y = self.goal_y;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const max_g_score = std.math.maxInt(u32);
        var g_scores = try allocator.alloc(u32, width * height);
        @memset(g_scores, max_g_score);

        var came_from_x = try allocator.alloc(i32, width * height);
        var came_from_y = try allocator.alloc(i32, width * height);
        @memset(came_from_x, -1);
        @memset(came_from_y, -1);

        var open_set = BinaryHeap.init(allocator);
        defer open_set.deinit();

        g_scores[start_y * width + start_x] = 0;
        const start_f = heuristicDistance(heuristic, start_x, start_y, goal_x, goal_y);
        try open_set.push(Node.init(start_x, start_y, start_f));

        const directions = if (move_type == .diagonal)
            ([_][2]i32{
                .{ 0, -1 },  .{ 1, 0 },  .{ 0, 1 }, .{ -1, 0 },
                .{ -1, -1 }, .{ 1, -1 }, .{ 1, 1 }, .{ -1, 1 },
            })[0..]
        else
            ([_][2]i32{
                .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 },
            })[0..];

        var nodes_explored: u32 = 0;

        while (!open_set.isEmpty()) {
            const current = open_set.pop() orelse break;

            if (current.x == goal_x and current.y == goal_y) {
                var path_length: u32 = 1;
                var x = current.x;
                var y = current.y;

                while (x != start_x or y != start_y) {
                    const idx = y * width + x;
                    const prev_x = @as(i32, @intCast(came_from_x[idx]));
                    const prev_y = @as(i32, @intCast(came_from_y[idx]));

                    if (prev_x < 0 or prev_y < 0) break;

                    x = @as(u32, @intCast(prev_x));
                    y = @as(u32, @intCast(prev_y));
                    path_length += 1;
                }

                return PathResult{
                    .found = true,
                    .length = path_length,
                    .nodes_explored = nodes_explored,
                };
            }

            nodes_explored += 1;
            const current_g = g_scores[current.y * width + current.x];

            for (directions) |dir| {
                const nx = @as(i32, @intCast(current.x)) + dir[0];
                const ny = @as(i32, @intCast(current.y)) + dir[1];

                if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(width)) or ny >= @as(i32, @intCast(height))) {
                    continue;
                }

                const unx = @as(u32, @intCast(nx));
                const uny = @as(u32, @intCast(ny));

                if (!maze_grid[uny * width + unx]) {
                    continue;
                }

                const move_cost: u32 = if (@abs(dir[0]) == 1 and @abs(dir[1]) == 1)
                    1414
                else
                    1000;

                const tentative_g = std.math.add(u32, current_g, move_cost) catch continue;
                const idx = uny * width + unx;

                if (tentative_g < g_scores[idx]) {
                    came_from_x[idx] = @as(i32, @intCast(current.x));
                    came_from_y[idx] = @as(i32, @intCast(current.y));
                    g_scores[idx] = tentative_g;

                    const f_score = std.math.add(u32, tentative_g, heuristicDistance(heuristic, unx, uny, goal_x, goal_y)) catch continue;
                    try open_set.push(Node.init(unx, uny, f_score));
                }
            }
        }

        return PathResult{ .found = false, .length = 0, .nodes_explored = nodes_explored };
    }

    fn estimateNodesExplored(
        self: *AStarPathfinder,
        maze_grid: []const bool,
        heuristic: Heuristic,
        move_type: Move,
    ) u32 {
        const width = self.width;
        const height = self.height;
        const start_x = self.start_x;
        const start_y = self.start_y;
        const goal_x = self.goal_x;
        const goal_y = self.goal_y;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const max_g_score = std.math.maxInt(u32);
        var g_scores = allocator.alloc(u32, width * height) catch return 0;
        defer allocator.free(g_scores);
        @memset(g_scores, max_g_score);

        var closed = allocator.alloc(bool, width * height) catch return 0;
        defer allocator.free(closed);
        @memset(closed, false);

        var open_set = BinaryHeap.init(allocator);
        defer open_set.deinit();

        g_scores[start_y * width + start_x] = 0;
        const start_f = heuristicDistance(heuristic, start_x, start_y, goal_x, goal_y);
        open_set.push(Node.init(start_x, start_y, start_f)) catch return 0;

        const directions = if (move_type == .diagonal)
            ([_][2]i32{
                .{ 0, -1 },  .{ 1, 0 },  .{ 0, 1 }, .{ -1, 0 },
                .{ -1, -1 }, .{ 1, -1 }, .{ 1, 1 }, .{ -1, 1 },
            })[0..]
        else
            ([_][2]i32{
                .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 },
            })[0..];

        var nodes_explored: u32 = 0;

        while (!open_set.isEmpty()) {
            const current = open_set.pop() orelse break;

            if (current.x == goal_x and current.y == goal_y) {
                break;
            }

            if (closed[current.y * width + current.x]) continue;

            closed[current.y * width + current.x] = true;
            nodes_explored += 1;

            const current_g = g_scores[current.y * width + current.x];

            for (directions) |dir| {
                const nx = @as(i32, @intCast(current.x)) + dir[0];
                const ny = @as(i32, @intCast(current.y)) + dir[1];

                if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(width)) or ny >= @as(i32, @intCast(height))) {
                    continue;
                }

                const unx = @as(u32, @intCast(nx));
                const uny = @as(u32, @intCast(ny));

                if (!maze_grid[uny * width + unx]) {
                    continue;
                }

                const move_cost: u32 = if (@abs(dir[0]) == 1 and @abs(dir[1]) == 1)
                    1414
                else
                    1000;

                const tentative_g = std.math.add(u32, current_g, move_cost) catch continue;
                const idx = uny * width + unx;

                if (tentative_g < g_scores[idx]) {
                    g_scores[idx] = tentative_g;
                    const f_score = std.math.add(u32, tentative_g, heuristicDistance(heuristic, unx, uny, goal_x, goal_y)) catch continue;
                    open_set.push(Node.init(unx, uny, f_score)) catch break;
                }
            }
        }

        return nodes_explored;
    }

    fn benchmarkDifferentApproaches(self: *AStarPathfinder, maze_grid: []const bool) struct { u32, u32, u32 } {
        const heuristics = [_]Heuristic{ .manhattan, .euclidean, .chebyshev };

        var total_paths_found: u32 = 0;
        var total_path_length: u32 = 0;
        var total_nodes_explored: u32 = 0;

        for (heuristics) |heuristic| {
            const path_result = self.findPath(maze_grid, heuristic, .cardinal) catch continue;
            if (path_result.found) {
                total_paths_found += 1;
                total_path_length += path_result.length;
                total_nodes_explored += self.estimateNodesExplored(maze_grid, heuristic, .cardinal);
            }
        }

        return .{ total_paths_found, total_path_length, total_nodes_explored };
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));

        // Получаем кэшированный лабиринт (должен быть сгенерирован в prepare)
        const maze_grid = self.ensureMazeGrid() catch return;

        var total_paths_found: u32 = 0;
        var total_path_length: u32 = 0;
        var total_nodes_explored: u32 = 0;

        // ТОЧНО как в C++: 10 итераций
        const iters = 10;

        for (0..iters) |_| {
            const result = self.benchmarkDifferentApproaches(maze_grid);
            total_paths_found += result[0];
            total_path_length += result[1];
            total_nodes_explored += result[2];
        }

        const paths_checksum = self.helper.checksumFloat(@as(f64, @floatFromInt(total_paths_found)));
        const length_checksum = self.helper.checksumFloat(@as(f64, @floatFromInt(total_path_length)));
        const nodes_checksum = self.helper.checksumFloat(@as(f64, @floatFromInt(total_nodes_explored)));

        self.result_val = (@as(u64, paths_checksum)) ^
            (@as(u64, length_checksum) << 16) ^
            (@as(u64, nodes_checksum) << 32);
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
