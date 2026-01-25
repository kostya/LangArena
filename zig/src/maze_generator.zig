// src/maze_generator.zig
const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const MazeGenerator = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: u32,
    height: u32,
    iterations: u32,
    result_val: i64, // ТОЧНО как в C++: int64_t result_val

    const Cell = enum(u8) { wall = 0, path = 1 };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    const Maze = struct {
        width: u32,
        height: u32,
        cells: []Cell,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Maze {
            const actual_width = if (width < 5) 5 else width;
            const actual_height = if (height < 5) 5 else height;
            const cells = try allocator.alloc(Cell, actual_width * actual_height);
            @memset(cells, Cell.wall);

            return Maze{
                .width = actual_width,
                .height = actual_height,
                .cells = cells,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Maze) void {
            self.allocator.free(self.cells);
        }

        inline fn get(self: *const Maze, x: u32, y: u32) Cell {
            return self.cells[y * self.width + x];
        }

        inline fn set(self: *Maze, x: u32, y: u32, cell: Cell) void {
            self.cells[y * self.width + x] = cell;
        }

        fn divide(self: *Maze, x1: u32, y1: u32, x2: u32, y2: u32, helper: *Helper) void {
            const width = @as(i32, @intCast(x2)) - @as(i32, @intCast(x1));
            const height = @as(i32, @intCast(y2)) - @as(i32, @intCast(y1));

            if (width < 2 or height < 2) return;

            const width_for_wall = @as(u32, @intCast(@max(width - 2, 0)));
            const height_for_wall = @as(u32, @intCast(@max(height - 2, 0)));
            const width_for_hole = @as(u32, @intCast(@max(width - 1, 0)));
            const height_for_hole = @as(u32, @intCast(@max(height - 1, 0)));

            if (width_for_wall == 0 or height_for_wall == 0 or
                width_for_hole == 0 or height_for_hole == 0) return;

            if (width > height) {
                // Вертикальная стена
                const wall_range = @max(width_for_wall / 2, 1);
                const wall_offset = if (wall_range > 0) helper.nextInt(@as(i32, @intCast(wall_range))) * 2 else 0;
                const wall_x = x1 + 2 + @as(u32, @intCast(wall_offset));

                const hole_range = @max(height_for_hole / 2, 1);
                const hole_offset = if (hole_range > 0) helper.nextInt(@as(i32, @intCast(hole_range))) * 2 else 0;
                const hole_y = y1 + 1 + @as(u32, @intCast(hole_offset));

                if (wall_x > x2 or hole_y > y2) return;

                // Рисуем стену с отверстием
                var y = y1;
                while (y <= y2) : (y += 1) {
                    if (y != hole_y) {
                        self.set(wall_x, y, Cell.wall);
                    }
                }

                // Рекурсивно делим левую и правую части
                if (wall_x > x1 + 1) self.divide(x1, y1, wall_x - 1, y2, helper);
                if (wall_x + 1 < x2) self.divide(wall_x + 1, y1, x2, y2, helper);
            } else {
                // Горизонтальная стена
                const wall_range = @max(height_for_wall / 2, 1);
                const wall_offset = if (wall_range > 0) helper.nextInt(@as(i32, @intCast(wall_range))) * 2 else 0;
                const wall_y = y1 + 2 + @as(u32, @intCast(wall_offset));

                const hole_range = @max(width_for_hole / 2, 1);
                const hole_offset = if (hole_range > 0) helper.nextInt(@as(i32, @intCast(hole_range))) * 2 else 0;
                const hole_x = x1 + 1 + @as(u32, @intCast(hole_offset));

                if (wall_y > y2 or hole_x > x2) return;

                // Рисуем стену с отверстием
                var x = x1;
                while (x <= x2) : (x += 1) {
                    if (x != hole_x) {
                        self.set(x, wall_y, Cell.wall);
                    }
                }

                // Рекурсивно делим верхнюю и нижнюю части
                if (wall_y > y1 + 1) self.divide(x1, y1, x2, wall_y - 1, helper);
                if (wall_y + 1 < y2) self.divide(x1, wall_y + 1, x2, y2, helper);
            }
        }

        fn isConnected(self: *const Maze, start_x: u32, start_y: u32, goal_x: u32, goal_y: u32) bool {
            if (start_x >= self.width or start_y >= self.height or
                goal_x >= self.width or goal_y >= self.height)
            {
                return false;
            }

            var visited = std.ArrayList(bool).empty;
            defer visited.deinit(self.allocator);

            visited.resize(self.allocator, self.width * self.height) catch return false;
            @memset(visited.items, false);

            var queue = std.ArrayList(struct { x: u32, y: u32 }).empty;
            defer queue.deinit(self.allocator);

            visited.items[start_y * self.width + start_x] = true;
            queue.append(self.allocator, .{ .x = start_x, .y = start_y }) catch return false;

            var front: usize = 0;
            while (front < queue.items.len) {
                const pos = queue.items[front];
                front += 1;

                if (pos.x == goal_x and pos.y == goal_y) return true;

                // Проверяем соседние клетки
                if (pos.y > 0) {
                    const nx = pos.x;
                    const ny = pos.y - 1;
                    const idx = ny * self.width + nx;
                    if (self.get(nx, ny) == Cell.path and !visited.items[idx]) {
                        visited.items[idx] = true;
                        queue.append(self.allocator, .{ .x = nx, .y = ny }) catch return false;
                    }
                }

                if (pos.x + 1 < self.width) {
                    const nx = pos.x + 1;
                    const ny = pos.y;
                    const idx = ny * self.width + nx;
                    if (self.get(nx, ny) == Cell.path and !visited.items[idx]) {
                        visited.items[idx] = true;
                        queue.append(self.allocator, .{ .x = nx, .y = ny }) catch return false;
                    }
                }

                if (pos.y + 1 < self.height) {
                    const nx = pos.x;
                    const ny = pos.y + 1;
                    const idx = ny * self.width + nx;
                    if (self.get(nx, ny) == Cell.path and !visited.items[idx]) {
                        visited.items[idx] = true;
                        queue.append(self.allocator, .{ .x = nx, .y = ny }) catch return false;
                    }
                }

                if (pos.x > 0) {
                    const nx = pos.x - 1;
                    const ny = pos.y;
                    const idx = ny * self.width + nx;
                    if (self.get(nx, ny) == Cell.path and !visited.items[idx]) {
                        visited.items[idx] = true;
                        queue.append(self.allocator, .{ .x = nx, .y = ny }) catch return false;
                    }
                }
            }

            return false;
        }

        fn generate(self: *Maze, helper: *Helper) void {
            if (self.width < 5 or self.height < 5) {
                // Создаем простой проход посередине
                const mid_y = self.height / 2;
                var x: u32 = 0;
                while (x < self.width) : (x += 1) {
                    self.set(x, mid_y, Cell.path);
                }
                return;
            }

            self.divide(0, 0, self.width - 1, self.height - 1, helper);
        }
    };

    // ТОЧНАЯ копия статического метода из C++
    pub fn generateWalkableMaze(allocator: std.mem.Allocator, width: u32, height: u32, helper: *Helper) ![]bool {
        // В C++: Maze maze(width, height);
        var maze = try Maze.init(allocator, width, height);
        defer maze.deinit();

        // В C++: maze.generate();
        maze.generate(helper);

        // В C++: std::pair<int, int> start = {1, 1};
        // В C++: std::pair<int, int> goal = {width - 2, height - 2};
        const start_x: u32 = 1;
        const start_y: u32 = 1;
        const goal_x = if (width >= 2) width - 2 else 0;
        const goal_y = if (height >= 2) height - 2 else 0;

        // В C++: if (!maze.is_connected(start, goal)) {
        if (!maze.isConnected(start_x, start_y, goal_x, goal_y)) {
            // В C++: делаем границы проходимыми
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                if (x < maze.width) {
                    if (x == 1 or x == width - 2) {
                        var y: u32 = 0;
                        while (y < height) : (y += 1) {
                            if (y < maze.height) {
                                maze.set(x, y, Cell.path);
                            }
                        }
                    }
                }
            }

            var y: u32 = 0;
            while (y < height) : (y += 1) {
                if (y < maze.height) {
                    if (y == 1 or y == height - 2) {
                        var x2: u32 = 0;
                        while (x2 < width) : (x2 += 1) {
                            if (x2 < maze.width) {
                                maze.set(x2, y, Cell.path);
                            }
                        }
                    }
                }
            }
        }

        // В C++: return maze.to_bool_grid();
        const result = try allocator.alloc(bool, maze.width * maze.height);
        for (0..maze.height) |y| {
            for (0..maze.width) |x| {
                result[y * maze.width + x] = maze.get(@as(u32, @intCast(x)), @as(u32, @intCast(y))) == Cell.path;
            }
        }

        return result;
    }

    // ТОЧНЫЙ конструктор как в C++
    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeGenerator {
        // В C++: iterations_count берется из INPUT
        const iterations_count = helper.getInputInt("MazeGenerator");

        const self = try allocator.create(MazeGenerator);
        // В C++: width_(1001), height_(1001) - всегда 1001
        // В C++: result_val(0)
        self.* = MazeGenerator{
            .allocator = allocator,
            .helper = helper,
            .width = 1001, // ТОЧНО как в C++: width_(1001)
            .height = 1001, // ТОЧНО как в C++: height_(1001)
            .iterations = if (iterations_count > 0) @as(u32, @intCast(iterations_count)) else 0,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *MazeGenerator) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeGenerator) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));

        // ТОЧНО как в C++: uint64_t checksum = 0;
        var checksum: u64 = 0;

        // ТОЧНО как в C++: int iters = iterations();
        const iters = self.iterations;

        // ТОЧНО как в C++ цикл
        for (0..iters) |_| {
            // ОТДЕЛЬНЫЙ arena для каждой итерации
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit(); // Освобождается после каждой итерации!
            const arena_allocator = arena.allocator();

            // ТОЧНО как в C++: auto bool_grid = Maze::generate_walkable_maze(width_, height_);
            const bool_grid = generateWalkableMaze(arena_allocator, self.width, self.height, self.helper) catch continue;
            // НЕ нужно defer free - arena очистит всё сам

            // ТОЧНЫЙ цикл как в C++
            for (0..self.height) |y| {
                const y_u64 = @as(u64, @intCast(y));
                for (0..self.width) |x| {
                    if (!bool_grid[y * self.width + x]) {
                        const x_u64 = @as(u64, @intCast(x));
                        checksum = checksum +% (x_u64 * y_u64);
                    }
                }
            }
            
            // arena.deinit() здесь очистит ВСЮ память этой итерации
        }

        // ТОЧНО как в C++: result_val = static_cast<int64_t>(checksum);
        self.result_val = @as(i64, @bitCast(checksum));
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        // В C++: int64_t result() const { return result_val; }
        // Но в нашей системе бенчмарков ожидается u32
        // Возвращаем младшие 32 бита как делается в других бенчмарках
        return @as(u32, @truncate(@as(u64, @bitCast(self.result_val))));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
