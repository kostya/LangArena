const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const MazeGenerator = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*Maze,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    pub const CellKind = enum(u8) {
        wall = 0,
        space = 1,
        start = 2,
        finish = 3,
        border = 4,
        path = 5,

        pub fn isWalkable(self: CellKind) bool {
            return self == .space or self == .start or self == .finish;
        }
    };

    pub const Cell = struct {
        kind: CellKind,
        neighbors: std.ArrayListUnmanaged(*Cell),
        x: i32,
        y: i32,

        pub fn init(allocator: std.mem.Allocator, x: i32, y: i32) !*Cell {
            const self = try allocator.create(Cell);
            self.* = Cell{
                .kind = .wall,
                .neighbors = .empty,
                .x = x,
                .y = y,
            };
            return self;
        }

        pub fn deinit(self: *Cell, allocator: std.mem.Allocator) void {
            self.neighbors.deinit(allocator);
            allocator.destroy(self);
        }

        pub fn addNeighbor(self: *Cell, allocator: std.mem.Allocator, cell: *Cell) !void {
            try self.neighbors.append(allocator, cell);
        }

        pub fn reset(self: *Cell) void {
            if (self.kind == .space) {
                self.kind = .wall;
            }
        }
    };

    pub const Maze = struct {
        width: i32,
        height: i32,
        cells: []*Cell,
        start: *Cell,
        finish: *Cell,
        allocator: std.mem.Allocator,
        helper: *Helper,

        pub fn init(allocator: std.mem.Allocator, helper: *Helper, width: i32, height: i32) !*Maze {
            const w = @max(width, 5);
            const h = @max(height, 5);

            const cells = try allocator.alloc(*Cell, @intCast(w * h));
            errdefer allocator.free(cells);

            var y: i32 = 0;
            while (y < h) : (y += 1) {
                var x: i32 = 0;
                while (x < w) : (x += 1) {
                    const idx = @as(usize, @intCast(y * w + x));
                    cells[idx] = try Cell.init(allocator, x, y);
                }
            }

            const start = cells[@as(usize, @intCast(1 * w + 1))];
            const finish = cells[@as(usize, @intCast((h - 2) * w + (w - 2)))];
            start.kind = .start;
            finish.kind = .finish;

            const self = try allocator.create(Maze);
            self.* = Maze{
                .width = w,
                .height = h,
                .cells = cells,
                .start = start,
                .finish = finish,
                .allocator = allocator,
                .helper = helper,
            };

            try self.updateNeighbors();
            return self;
        }

        pub fn deinit(self: *Maze) void {
            for (self.cells) |cell| {
                cell.deinit(self.allocator);
            }
            self.allocator.free(self.cells);
            self.allocator.destroy(self);
        }

        fn getIdx(self: *const Maze, y: i32, x: i32) usize {
            return @intCast(y * self.width + x);
        }

        pub fn updateNeighbors(self: *Maze) !void {
            var y: i32 = 0;
            while (y < self.height) : (y += 1) {
                var x: i32 = 0;
                while (x < self.width) : (x += 1) {
                    const cell = self.cells[self.getIdx(y, x)];
                    cell.neighbors.clearRetainingCapacity();

                    if (x > 0 and y > 0 and x < self.width - 1 and y < self.height - 1) {
                        try cell.addNeighbor(self.allocator, self.cells[self.getIdx(y - 1, x)]);
                        try cell.addNeighbor(self.allocator, self.cells[self.getIdx(y + 1, x)]);
                        try cell.addNeighbor(self.allocator, self.cells[self.getIdx(y, x + 1)]);
                        try cell.addNeighbor(self.allocator, self.cells[self.getIdx(y, x - 1)]);

                        var t: usize = 0;
                        while (t < 4) : (t += 1) {
                            const i = self.helper.nextInt(4);
                            const j = self.helper.nextInt(4);
                            if (i != j) {
                                const temp = cell.neighbors.items[@intCast(i)];
                                cell.neighbors.items[@intCast(i)] = cell.neighbors.items[@intCast(j)];
                                cell.neighbors.items[@intCast(j)] = temp;
                            }
                        }
                    } else {
                        cell.kind = .border;
                    }
                }
            }
        }

        pub fn reset(self: *Maze) void {
            for (self.cells) |cell| {
                cell.reset();
            }
            self.start.kind = .start;
            self.finish.kind = .finish;
        }

        pub fn dig(self: *Maze, start_cell: *Cell) !void {
            var stack = try std.ArrayListUnmanaged(*Cell).initCapacity(self.allocator, @intCast(self.width * self.height));
            defer stack.deinit(self.allocator);

            stack.appendAssumeCapacity(start_cell);
            var stack_ptr: usize = 1;

            while (stack_ptr > 0) {
                stack_ptr -= 1;
                const cell = stack.items[stack_ptr];

                var walkable: u32 = 0;
                const neighbors = cell.neighbors.items;
                for (neighbors) |n| {
                    if (n.kind.isWalkable()) {
                        walkable += 1;
                    }
                }

                if (walkable == 1) {
                    cell.kind = .space;
                    for (neighbors) |n| {
                        if (n.kind == .wall) {
                            if (stack_ptr >= stack.items.len) {
                                try stack.append(self.allocator, n);
                            } else {
                                stack.items[stack_ptr] = n;
                            }
                            stack_ptr += 1;
                        }
                    }
                }
            }
        }

        pub fn ensureOpenFinish(self: *Maze, start_cell: *Cell) !void {
            var stack = try std.ArrayListUnmanaged(*Cell).initCapacity(self.allocator, @intCast(self.width * self.height));
            defer stack.deinit(self.allocator);

            stack.appendAssumeCapacity(start_cell);
            var stack_ptr: usize = 1;

            while (stack_ptr > 0) {
                stack_ptr -= 1;
                const cell = stack.items[stack_ptr];

                cell.kind = .space;

                var walkable: u32 = 0;
                const neighbors = cell.neighbors.items;
                for (neighbors) |n| {
                    if (n.kind.isWalkable()) {
                        walkable += 1;
                    }
                }

                if (walkable > 1) {
                    continue;
                }

                for (neighbors) |n| {
                    if (n.kind == .wall) {
                        if (stack_ptr >= stack.items.len) {
                            try stack.append(self.allocator, n);
                        } else {
                            stack.items[stack_ptr] = n;
                        }
                        stack_ptr += 1;
                    }
                }
            }
        }

        pub fn generate(self: *Maze) !void {
            for (self.start.neighbors.items) |n| {
                if (n.kind == .wall) {
                    try self.dig(n);
                }
            }

            for (self.finish.neighbors.items) |n| {
                if (n.kind == .wall) {
                    try self.ensureOpenFinish(n);
                }
            }
        }

        pub fn middleCell(self: *const Maze) *Cell {
            return self.cells[self.getIdx(@divTrunc(self.height, 2), @divTrunc(self.width, 2))];
        }

        pub fn checksum(self: *const Maze) u32 {
            var hasher: u32 = 2166136261;
            const prime: u32 = 16777619;

            for (self.cells) |cell| {
                if (cell.kind == .space) {
                    const val = @as(u32, @intCast(cell.x * cell.y));
                    hasher = (hasher ^ val) *% prime;
                }
            }
            return hasher;
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeGenerator {
        const w = helper.config_i64("Maze::Generator", "w");
        const h = helper.config_i64("Maze::Generator", "h");
        const self = try allocator.create(MazeGenerator);
        self.* = MazeGenerator{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = null,
        };
        return self;
    }

    pub fn deinit(self: *MazeGenerator) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeGenerator) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::Generator");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.maze = Maze.init(self.allocator, self.helper, self.width, self.height) catch return;
        self.result_val = 0;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            m.reset();
            m.generate() catch return;
            self.result_val +%= @intFromEnum(m.middleCell().kind);
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            return self.result_val +% m.checksum();
        }
        return 0;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeGenerator = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const MazeBFS = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*MazeGenerator.Maze,
    path: std.ArrayListUnmanaged(*MazeGenerator.Cell),

    const PathNode = struct {
        cell: *MazeGenerator.Cell,
        parent: i32,
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeBFS {
        const w = helper.config_i64("Maze::BFS", "w");
        const h = helper.config_i64("Maze::BFS", "h");
        const self = try allocator.create(MazeBFS);
        self.* = MazeBFS{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = null,
            .path = .empty,
        };
        return self;
    }

    pub fn deinit(self: *MazeBFS) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.path.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeBFS) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::BFS");
    }

    fn bfs(self: *MazeBFS, start: *MazeGenerator.Cell, target: *MazeGenerator.Cell) !std.ArrayListUnmanaged(*MazeGenerator.Cell) {
        if (start == target) {
            var result = std.ArrayListUnmanaged(*MazeGenerator.Cell){};
            try result.append(self.allocator, start);
            return result;
        }

        var queue = std.ArrayListUnmanaged(i32){};
        defer queue.deinit(self.allocator);

        const visited = try self.allocator.alloc(bool, @intCast(self.width * self.height));
        defer self.allocator.free(visited);
        @memset(visited, false);

        var path_nodes = std.ArrayListUnmanaged(PathNode){};
        defer path_nodes.deinit(self.allocator);

        visited[@intCast(start.y * self.width + start.x)] = true;
        try path_nodes.append(self.allocator, PathNode{ .cell = start, .parent = -1 });
        try queue.append(self.allocator, 0);

        while (queue.items.len > 0) {
            const path_id = queue.orderedRemove(0);
            const node = path_nodes.items[@intCast(path_id)];

            for (node.cell.neighbors.items) |neighbor| {
                if (neighbor == target) {
                    var result = std.ArrayListUnmanaged(*MazeGenerator.Cell){};
                    errdefer result.deinit(self.allocator);
                    try result.append(self.allocator, target);
                    var cur = path_id;
                    while (cur >= 0) {
                        try result.append(self.allocator, path_nodes.items[@intCast(cur)].cell);
                        cur = path_nodes.items[@intCast(cur)].parent;
                    }
                    std.mem.reverse(*MazeGenerator.Cell, result.items);
                    return result;
                }

                if (neighbor.kind.isWalkable()) {
                    const n_idx = @as(usize, @intCast(neighbor.y * self.width + neighbor.x));
                    if (!visited[n_idx]) {
                        visited[n_idx] = true;
                        try path_nodes.append(self.allocator, PathNode{ .cell = neighbor, .parent = path_id });
                        try queue.append(self.allocator, @intCast(path_nodes.items.len - 1));
                    }
                }
            }
        }

        return std.ArrayListUnmanaged(*MazeGenerator.Cell){};
    }

    fn midCellChecksum(path: std.ArrayListUnmanaged(*MazeGenerator.Cell)) u32 {
        if (path.items.len == 0) return 0;
        const cell = path.items[path.items.len / 2];
        return @intCast(cell.x * cell.y);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            self.path.deinit(self.allocator);
            self.path = self.bfs(m.start, m.finish) catch return;
            self.result_val +%= @intCast(self.path.items.len);
        }
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        self.maze = MazeGenerator.Maze.init(self.allocator, self.helper, self.width, self.height) catch return;
        self.maze.?.generate() catch return;
        self.result_val = 0;
        self.path = .empty;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        return self.result_val +% midCellChecksum(self.path);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeBFS = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const MazeAStar = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    width: i32,
    height: i32,
    result_val: u32,
    maze: ?*MazeGenerator.Maze,
    path: std.ArrayListUnmanaged(*MazeGenerator.Cell),

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

        fn push(self: *PriorityQueue, vertex: i32, priority: i32) !void {
            if (self.size >= self.vertices.len) {
                self.vertices = try self.allocator.realloc(self.vertices, self.vertices.len * 2);
                self.priorities = try self.allocator.realloc(self.priorities, self.priorities.len * 2);
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

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*MazeAStar {
        const w = helper.config_i64("Maze::AStar", "w");
        const h = helper.config_i64("Maze::AStar", "h");
        const self = try allocator.create(MazeAStar);
        self.* = MazeAStar{
            .allocator = allocator,
            .helper = helper,
            .width = @intCast(w),
            .height = @intCast(h),
            .result_val = 0,
            .maze = null,
            .path = .empty,
        };
        return self;
    }

    pub fn deinit(self: *MazeAStar) void {
        if (self.maze) |m| {
            m.deinit();
        }
        self.path.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *MazeAStar) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Maze::AStar");
    }

    fn heuristic(a: *MazeGenerator.Cell, b: *MazeGenerator.Cell) i32 {
        const dx = if (a.x > b.x) a.x - b.x else b.x - a.x;
        const dy = if (a.y > b.y) a.y - b.y else b.y - a.y;
        return dx + dy;
    }

    fn astar(self: *MazeAStar, start: *MazeGenerator.Cell, target: *MazeGenerator.Cell) !std.ArrayListUnmanaged(*MazeGenerator.Cell) {
        if (start == target) {
            var result = std.ArrayListUnmanaged(*MazeGenerator.Cell){};
            try result.append(self.allocator, start);
            return result;
        }

        const size = @as(usize, @intCast(self.width * self.height));
        const came_from = try self.allocator.alloc(i32, size);
        defer self.allocator.free(came_from);
        const g_score = try self.allocator.alloc(i32, size);
        defer self.allocator.free(g_score);
        const best_f = try self.allocator.alloc(i32, size);
        defer self.allocator.free(best_f);

        for (0..size) |i| {
            came_from[i] = -1;
            g_score[i] = std.math.maxInt(i32);
            best_f[i] = std.math.maxInt(i32);
        }

        const start_idx = @as(usize, @intCast(start.y * self.width + start.x));
        const target_idx = @as(usize, @intCast(target.y * self.width + target.x));

        var open_set = try PriorityQueue.init(self.allocator, size);
        defer open_set.deinit();

        var in_open = try self.allocator.alloc(u8, size);
        defer self.allocator.free(in_open);
        @memset(in_open, 0);

        g_score[start_idx] = 0;
        const f_start = heuristic(start, target);
        try open_set.push(@intCast(start_idx), f_start);
        best_f[start_idx] = f_start;
        in_open[start_idx] = 1;

        while (open_set.size > 0) {
            const current_idx = open_set.pop() orelse break;
            in_open[@intCast(current_idx)] = 0;

            if (current_idx == target_idx) {
                var result = std.ArrayListUnmanaged(*MazeGenerator.Cell){};
                errdefer result.deinit(self.allocator);
                var cur = @as(i32, @intCast(current_idx));
                while (cur != -1) {
                    const cell = self.maze.?.cells[@intCast(cur)];
                    try result.append(self.allocator, cell);
                    cur = came_from[@intCast(cur)];
                }
                std.mem.reverse(*MazeGenerator.Cell, result.items);
                return result;
            }

            const current_g = g_score[@intCast(current_idx)];
            const current_cell = self.maze.?.cells[@intCast(current_idx)];

            for (current_cell.neighbors.items) |neighbor| {
                if (!neighbor.kind.isWalkable()) continue;

                const neighbor_idx = @as(usize, @intCast(neighbor.y * self.width + neighbor.x));
                const tentative_g = current_g + 1;

                if (tentative_g < g_score[neighbor_idx]) {
                    came_from[neighbor_idx] = @intCast(current_idx);
                    g_score[neighbor_idx] = tentative_g;
                    const f_new = tentative_g + heuristic(neighbor, target);

                    if (f_new < best_f[neighbor_idx]) {
                        best_f[neighbor_idx] = f_new;
                        if (in_open[neighbor_idx] == 0) {
                            try open_set.push(@intCast(neighbor_idx), f_new);
                            in_open[neighbor_idx] = 1;
                        }
                    }
                }
            }
        }

        return std.ArrayListUnmanaged(*MazeGenerator.Cell){};
    }

    fn midCellChecksum(path: std.ArrayListUnmanaged(*MazeGenerator.Cell)) u32 {
        if (path.items.len == 0) return 0;
        const cell = path.items[path.items.len / 2];
        return @intCast(cell.x * cell.y);
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        if (self.maze) |m| {
            self.path.deinit(self.allocator);
            self.path = self.astar(m.start, m.finish) catch return;
            self.result_val +%= @intCast(self.path.items.len);
        }
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        self.maze = MazeGenerator.Maze.init(self.allocator, self.helper, self.width, self.height) catch return;
        self.maze.?.generate() catch return;
        self.result_val = 0;
        self.path = .empty;
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        return self.result_val +% midCellChecksum(self.path);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *MazeAStar = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
