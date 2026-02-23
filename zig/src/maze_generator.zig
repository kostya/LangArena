const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const MazeGenerator = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    bool_grid: ?[]const []const bool,
    result_val: u32,

    const Cell = enum(u8) { wall = 0, path = 1 };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    const Maze = struct {
        width: i32,
        height: i32,
        cells: []Cell,
        allocator: std.mem.Allocator,
        helper: *Helper,

        fn init(allocator: std.mem.Allocator, helper: *Helper, width: i32, height: i32) !Maze {
            const actual_width = if (width < 5) 5 else width;
            const actual_height = if (height < 5) 5 else height;
            const cells = try allocator.alloc(Cell, @as(usize, @intCast(actual_width * actual_height)));
            @memset(cells, Cell.wall);

            return Maze{
                .width = actual_width,
                .height = actual_height,
                .cells = cells,
                .allocator = allocator,
                .helper = helper,
            };
        }

        fn deinit(self: *Maze) void {
            self.allocator.free(self.cells);
        }

        fn get(self: *const Maze, x: i32, y: i32) Cell {
            if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
                return Cell.wall;
            }
            return self.cells[@as(usize, @intCast(y * self.width + x))];
        }

        fn set(self: *Maze, x: i32, y: i32, cell: Cell) void {
            if (x >= 0 and x < self.width and y >= 0 and y < self.height) {
                self.cells[@as(usize, @intCast(y * self.width + x))] = cell;
            }
        }

        fn addRandomPaths(self: *Maze) void {
            const num_extra_paths = @as(i32, @intCast(@divTrunc(self.width * self.height, 20)));
            var i: i32 = 0;
            while (i < num_extra_paths) : (i += 1) {
                const x = self.helper.nextInt(self.width - 2) + 1;
                const y = self.helper.nextInt(self.height - 2) + 1;

                if (x >= 1 and x < self.width - 1 and y >= 1 and y < self.height - 1) {
                    if (self.get(x, y) == Cell.wall and
                        self.get(x - 1, y) == Cell.wall and
                        self.get(x + 1, y) == Cell.wall and
                        self.get(x, y - 1) == Cell.wall and
                        self.get(x, y + 1) == Cell.wall)
                    {
                        self.set(x, y, Cell.path);
                    }
                }
            }
        }

        fn divide(self: *Maze, x1: i32, y1: i32, x2: i32, y2: i32) void {
            const width = x2 - x1;
            const height = y2 - y1;

            if (width < 2 or height < 2) return;

            const width_for_wall = @max(width - 2, 0);
            const height_for_wall = @max(height - 2, 0);
            const width_for_hole = @max(width - 1, 0);
            const height_for_hole = @max(height - 1, 0);

            if (width_for_wall == 0 or height_for_wall == 0 or
                width_for_hole == 0 or height_for_hole == 0) return;

            if (width > height) {
                const wall_range = @max(@divTrunc(width_for_wall, 2), 1);
                const wall_offset = if (wall_range > 0) self.helper.nextInt(@as(i32, @intCast(wall_range))) * 2 else 0;
                const wall_x = x1 + 2 + wall_offset;

                const hole_range = @max(@divTrunc(height_for_hole, 2), 1);
                const hole_offset = if (hole_range > 0) self.helper.nextInt(@as(i32, @intCast(hole_range))) * 2 else 0;
                const hole_y = y1 + 1 + hole_offset;

                if (wall_x > x2 or hole_y > y2) return;

                var y = y1;
                while (y <= y2) : (y += 1) {
                    if (y != hole_y) {
                        self.set(wall_x, y, Cell.wall);
                    }
                }

                if (wall_x > x1 + 1) self.divide(x1, y1, wall_x - 1, y2);
                if (wall_x + 1 < x2) self.divide(wall_x + 1, y1, x2, y2);
            } else {
                const wall_range = @max(@divTrunc(height_for_wall, 2), 1);
                const wall_offset = if (wall_range > 0) self.helper.nextInt(@as(i32, @intCast(wall_range))) * 2 else 0;
                const wall_y = y1 + 2 + wall_offset;

                const hole_range = @max(@divTrunc(width_for_hole, 2), 1);
                const hole_offset = if (hole_range > 0) self.helper.nextInt(@as(i32, @intCast(hole_range))) * 2 else 0;
                const hole_x = x1 + 1 + hole_offset;

                if (wall_y > y2 or hole_x > x2) return;

                var x = x1;
                while (x <= x2) : (x += 1) {
                    if (x != hole_x) {
                        self.set(x, wall_y, Cell.wall);
                    }
                }

                if (wall_y > y1 + 1) self.divide(x1, y1, x2, wall_y - 1);
                if (wall_y + 1 < y2) self.divide(x1, wall_y + 1, x2, y2);
            }
        }

        fn isConnected(self: *const Maze, start_x: i32, start_y: i32, goal_x: i32, goal_y: i32) bool {
            if (start_x < 0 or start_x >= self.width or start_y < 0 or start_y >= self.height or
                goal_x < 0 or goal_x >= self.width or goal_y < 0 or goal_y >= self.height)
            {
                return false;
            }

            var visited = self.allocator.alloc(bool, @as(usize, @intCast(self.width * self.height))) catch return false;
            defer self.allocator.free(visited);
            @memset(visited, false);

            var queue = std.ArrayList([2]i32).initCapacity(self.allocator, @as(usize, @intCast(self.width * self.height))) catch return false;
            defer queue.deinit(self.allocator);

            visited[@as(usize, @intCast(start_y * self.width + start_x))] = true;
            queue.append(self.allocator, .{ start_x, start_y }) catch return false;

            var queue_index: usize = 0;

            while (queue_index < queue.items.len) {
                const current = queue.items[queue_index];
                queue_index += 1;
                const x = current[0];
                const y = current[1];

                if (x == goal_x and y == goal_y) {
                    return true;
                }

                if (y > 0 and self.get(x, y - 1) == Cell.path) {
                    const idx = @as(usize, @intCast((y - 1) * self.width + x));
                    if (!visited[idx]) {
                        visited[idx] = true;
                        queue.append(self.allocator, .{ x, y - 1 }) catch return false;
                    }
                }

                if (x + 1 < self.width and self.get(x + 1, y) == Cell.path) {
                    const idx = @as(usize, @intCast(y * self.width + (x + 1)));
                    if (!visited[idx]) {
                        visited[idx] = true;
                        queue.append(self.allocator, .{ x + 1, y }) catch return false;
                    }
                }

                if (y + 1 < self.height and self.get(x, y + 1) == Cell.path) {
                    const idx = @as(usize, @intCast((y + 1) * self.width + x));
                    if (!visited[idx]) {
                        visited[idx] = true;
                        queue.append(self.allocator, .{ x, y + 1 }) catch return false;
                    }
                }

                if (x > 0 and self.get(x - 1, y) == Cell.path) {
                    const idx = @as(usize, @intCast(y * self.width + (x - 1)));
                    if (!visited[idx]) {
                        visited[idx] = true;
                        queue.append(self.allocator, .{ x - 1, y }) catch return false;
                    }
                }
            }

            return false;
        }

        fn generate(self: *Maze) void {
            if (self.width < 5 or self.height < 5) {
                const mid_y = @divTrunc(self.height, 2);
                var x: i32 = 0;
                while (x < self.width) : (x += 1) {
                    self.set(x, mid_y, Cell.path);
                }
                return;
            }

            self.divide(0, 0, self.width - 1, self.height - 1);

            self.addRandomPaths();
        }

        fn toBoolGrid(self: *Maze) ![]const []const bool {
            const rows = try self.allocator.alloc([]bool, @as(usize, @intCast(self.height)));
            errdefer self.allocator.free(rows);

            for (0..@as(usize, @intCast(self.height))) |i| {
                const row = try self.allocator.alloc(bool, @as(usize, @intCast(self.width)));
                errdefer for (0..i) |j| self.allocator.free(rows[j]);

                for (0..@as(usize, @intCast(self.width))) |j| {
                    row[j] = self.get(@as(i32, @intCast(j)), @as(i32, @intCast(i))) == Cell.path;
                }
                rows[i] = row;
            }

            return rows;
        }
    };

    pub fn generateWalkableMaze(allocator: std.mem.Allocator, helper: *Helper, width: i32, height: i32) ![]const []const bool {
        var maze = try Maze.init(allocator, helper, width, height);
        defer maze.deinit();
        maze.generate();

        const start_x: i32 = 1;
        const start_y: i32 = 1;
        const goal_x = width - 2;
        const goal_y = height - 2;

        if (!maze.isConnected(start_x, start_y, goal_x, goal_y)) {
            var x: i32 = 0;
            while (x < width) : (x += 1) {
                var y: i32 = 0;
                while (y < height) : (y += 1) {
                    if (x == 1 or y == 1 or x == width - 2 or y == height - 2) {
                        maze.set(x, y, Cell.path);
                    }
                }
            }
        }

        return maze.toBoolGrid();
    }

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeGenerator {
        const w = helper.config_i64("MazeGenerator", "w");
        const h = helper.config_i64("MazeGenerator", "h");
        const self = try allocator.create(MazeGenerator);
        self.* = MazeGenerator{
            .allocator = allocator,
            .helper = helper,
            .width = @as(i32, @intCast(w)),
            .height = @as(i32, @intCast(h)),
            .bool_grid = null,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *MazeGenerator) void {
        if (self.bool_grid) |grid| {
            for (grid) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(grid);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeGenerator) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "MazeGenerator");
    }

    fn gridChecksum(grid: []const []const bool) u32 {
        var hasher: u32 = 2166136261;
        const prime: u32 = 16777619;
        for (grid) |row| {
            for (row, 0..) |cell, j| {
                if (cell) {
                    const j_squared = @as(u32, @intCast(j * j));
                    hasher = (hasher ^ j_squared) *% prime;
                }
            }
        }
        return hasher;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));

        if (self.bool_grid) |old_grid| {
            for (old_grid) |row| {
                self.allocator.free(row);
            }
            self.allocator.free(old_grid);
        }

        if (generateWalkableMaze(self.allocator, self.helper, self.width, self.height)) |grid| {
            self.bool_grid = grid;
        } else |_| {
            self.bool_grid = null;
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        if (self.bool_grid) |grid| {
            return gridChecksum(grid);
        }
        return 0;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
