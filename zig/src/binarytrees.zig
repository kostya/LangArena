const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BinarytreesObj = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const TreeNode = struct {
        item: i32,
        left: ?*TreeNode,
        right: ?*TreeNode,

        fn create(allocator: std.mem.Allocator, item: i32, depth: i32) !*TreeNode {
            const node = try allocator.create(TreeNode);
            node.* = TreeNode{
                .item = item,
                .left = null,
                .right = null,
            };

            if (depth > 0) {
                node.left = try TreeNode.create(allocator, item - (@as(i32, 1) << @intCast(depth - 1)), depth - 1);
                node.right = try TreeNode.create(allocator, item + (@as(i32, 1) << @intCast(depth - 1)), depth - 1);
            }

            return node;
        }

        fn destroy(self: *TreeNode, allocator: std.mem.Allocator) void {
            if (self.left) |left| left.destroy(allocator);
            if (self.right) |right| right.destroy(allocator);
            allocator.destroy(self);
        }

        fn sum(self: *const TreeNode) u32 {
            var total: u32 = @as(u32, @bitCast(self.item)) +% 1;
            if (self.left) |left| total +%= left.sum();
            if (self.right) |right| total +%= right.sum();
            return total;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BinarytreesObj {
        const n = helper.config_i64("Binarytrees::Obj", "depth");

        const self = try allocator.create(BinarytreesObj);
        errdefer allocator.destroy(self);

        self.* = BinarytreesObj{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BinarytreesObj) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BinarytreesObj) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Binarytrees::Obj");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));

        const root = TreeNode.create(self.allocator, 0, @intCast(self.n)) catch return;
        defer root.destroy(self.allocator);

        self.result_val +%= root.sum();
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const BinarytreesArena = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const TreeNode = struct {
        item: i32,
        left: ?*TreeNode,
        right: ?*TreeNode,

        fn create(allocator: std.mem.Allocator, item: i32, depth: i32) !*TreeNode {
            const node = try allocator.create(TreeNode);
            node.* = TreeNode{
                .item = item,
                .left = null,
                .right = null,
            };

            if (depth > 0) {
                node.left = try TreeNode.create(allocator, item - (@as(i32, 1) << @intCast(depth - 1)), depth - 1);
                node.right = try TreeNode.create(allocator, item + (@as(i32, 1) << @intCast(depth - 1)), depth - 1);
            }

            return node;
        }

        fn sum(self: *const TreeNode) u32 {
            var total: u32 = @as(u32, @bitCast(self.item)) +% 1;
            if (self.left) |left| total +%= left.sum();
            if (self.right) |right| total +%= right.sum();
            return total;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BinarytreesArena {
        const n = helper.config_i64("Binarytrees::Arena", "depth");

        const self = try allocator.create(BinarytreesArena);
        errdefer allocator.destroy(self);

        self.* = BinarytreesArena{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BinarytreesArena) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BinarytreesArena) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Binarytrees::Arena");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const allocator = arena.allocator();

        const root = TreeNode.create(allocator, 0, @intCast(self.n)) catch return;
        self.result_val +%= root.sum();
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
