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
    
    // Кэшируемые массивы для findPath
    g_scores_cache: ?[][]i32 = null,
    came_from_cache: ?[][]i32 = null,

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
        return self;
    }

    pub fn deinit(self: *AStarPathfinder) void {
        if (self.maze_grid) |grid| {
            for (grid) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(grid);
        }
        
        // Освобождаем кэшированные массивы
        if (self.g_scores_cache) |g_scores| {
            for (g_scores) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(g_scores);
        }
        
        if (self.came_from_cache) |came_from| {
            for (came_from) |row| {
                self.allocator.free(row);
            }
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

    fn initCachedArrays(self: *AStarPathfinder) !void {
        if (self.g_scores_cache == null) {
            const width_usize = @as(usize, @intCast(self.width));
            const height_usize = @as(usize, @intCast(self.height));
            
            // Выделяем g_scores
            const g_scores = try self.allocator.alloc([]i32, height_usize);
            for (0..height_usize) |i| {
                g_scores[i] = try self.allocator.alloc(i32, width_usize);
            }
            self.g_scores_cache = g_scores;
            
            // Выделяем came_from
            const came_from = try self.allocator.alloc([]i32, height_usize);
            for (0..height_usize) |i| {
                came_from[i] = try self.allocator.alloc(i32, width_usize);
            }
            self.came_from_cache = came_from;
        }
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        _ = self.ensureMazeGrid() catch return;
        _ = self.initCachedArrays() catch return;
    }

    fn findPath(self: *AStarPathfinder, maze_grid: []const []const bool) struct { 
        path_length: i32, 
        nodes_explored: i32,
        found: bool 
    } {
        const width = self.width;
        const height = self.height;
        const start_x = self.start_x;
        const start_y = self.start_y;
        const goal_x = self.goal_x;
        const goal_y = self.goal_y;

        // Используем кэшированные массивы
        const g_scores = self.g_scores_cache.?;
        const came_from = self.came_from_cache.?;
        
        // Инициализация массивов
        const height_usize = @as(usize, @intCast(height));
        // const width_usize = @as(usize, @intCast(width));
        
        // Быстрая инициализация
        for (0..height_usize) |i| {
            @memset(g_scores[i], std.math.maxInt(i32));
            @memset(came_from[i], -1);
        }

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var open_set = NodeQueue.init(allocator, {});
        defer open_set.deinit();

        g_scores[@as(usize, @intCast(start_y))][@as(usize, @intCast(start_x))] = 0;
        const start_f = distance(start_x, start_y, goal_x, goal_y);
        open_set.add(Node.init(start_x, start_y, start_f)) catch return .{ 
            .path_length = 0, .nodes_explored = 0, .found = false 
        };

        const directions = [_][2]i32{ .{ 0, -1 }, .{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 } };
        var nodes_explored: i32 = 0;

        while (open_set.count() > 0) {
            const current = open_set.remove();
            nodes_explored += 1;

            if (current.x == goal_x and current.y == goal_y) {
                // Восстанавливаем путь
                var path_length: i32 = 1;
                var x = current.x;
                var y = current.y;
                
                while (x != start_x or y != start_y) {
                    const idx_y = @as(usize, @intCast(y));
                    const idx_x = @as(usize, @intCast(x));
                    const prev = came_from[idx_y][idx_x];
                    if (prev == -1) break;
                    
                    x = @mod(prev, width);
                    y = @divFloor(prev, width);
                    path_length += 1;
                }
                
                return .{ 
                    .path_length = path_length, 
                    .nodes_explored = nodes_explored, 
                    .found = true 
                };
            }

            const current_g = g_scores[@as(usize, @intCast(current.y))][@as(usize, @intCast(current.x))];

            for (directions) |dir| {
                const nx = current.x + dir[0];
                const ny = current.y + dir[1];

                if (nx < 0 or ny < 0 or nx >= width or ny >= height) continue;
                if (!maze_grid[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))]) continue;

                const tentative_g = current_g + 1000;
                const idx_y = @as(usize, @intCast(ny));
                const idx_x = @as(usize, @intCast(nx));

                if (tentative_g < g_scores[idx_y][idx_x]) {
                    // Упаковываем координаты в одно число
                    came_from[idx_y][idx_x] = current.y * width + current.x;
                    g_scores[idx_y][idx_x] = tentative_g;

                    const f_score = tentative_g + distance(nx, ny, goal_x, goal_y);
                    open_set.add(Node.init(nx, ny, f_score)) catch return .{ 
                        .path_length = 0, .nodes_explored = nodes_explored, .found = false 
                    };
                }
            }
        }

        return .{ .path_length = 0, .nodes_explored = nodes_explored, .found = false };
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *AStarPathfinder = @ptrCast(@alignCast(ptr));
        const maze_grid = self.ensureMazeGrid() catch return;
        const result = self.findPath(maze_grid);
        
        var local_result: i64 = 0;
        const path_size = if (result.found) result.path_length else 0;

        local_result = @as(i64, @intCast(@as(u64, @bitCast(local_result)) << 5)) + @as(i64, @intCast(path_size));
        local_result = @as(i64, @intCast(@as(u64, @bitCast(local_result)) << 5)) + @as(i64, @intCast(result.nodes_explored));
        
        self.result_val = @as(u32, @intCast(@as(i64, @intCast(self.result_val)) + local_result));
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