const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const Binarytrees = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const TreeNodePool = struct {
        buffer: []TreeNode,
        index: usize = 0,

        pub fn init(allocator: std.mem.Allocator, max_nodes: usize) !TreeNodePool {
            return TreeNodePool{
                .buffer = try allocator.alloc(TreeNode, max_nodes),
            };
        }

        pub fn deinit(self: *TreeNodePool, allocator: std.mem.Allocator) void {
            allocator.free(self.buffer);
        }

        pub fn allocNode(self: *TreeNodePool, item: i32) *TreeNode {
            const node = &self.buffer[self.index];
            node.* = TreeNode{
                .item = item,
                .left = null,
                .right = null,
            };
            self.index += 1;
            return node;
        }

        pub fn reset(self: *TreeNodePool) void {
            self.index = 0;
        }

        pub fn capacity(self: *const TreeNodePool) usize {
            return self.buffer.len;
        }
    };

    const TreeNode = struct {
        item: i32,
        left: ?*TreeNode,
        right: ?*TreeNode,

        pub fn create(pool: *TreeNodePool, item: i32, depth: i32) *TreeNode {
            const node = pool.allocNode(item);

            if (depth > 0) {
                node.left = TreeNode.create(pool, 2 * item - 1, depth - 1);
                node.right = TreeNode.create(pool, 2 * item, depth - 1);
            }

            return node;
        }

        pub fn check(self: *const TreeNode) i32 {
            if (self.left == null or self.right == null) {
                return self.item;
            }
            return self.left.?.check() - self.right.?.check() + self.item;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*Binarytrees {
        const n = helper.config_i64("Binarytrees", "depth");

        const self = try allocator.create(Binarytrees);
        errdefer allocator.destroy(self);

        self.* = Binarytrees{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *Binarytrees) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *Binarytrees) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Binarytrees");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *Binarytrees = @ptrCast(@alignCast(ptr));

        const min_depth: i32 = 4;
        const max_depth = @max(min_depth + 2, @as(i32, @intCast(self.n)));
        const stretch_depth = max_depth + 1;

        const max_nodes_for_depth = @as(usize, @intCast((@as(u32, 1) << @as(u5, @intCast(stretch_depth + 1))) - 1));
        var main_pool = TreeNodePool.init(self.allocator, max_nodes_for_depth) catch return;
        defer main_pool.deinit(self.allocator);

        {
            const stretch_tree = TreeNode.create(&main_pool, 0, stretch_depth);
            self.result_val +%= @as(u32, @bitCast(stretch_tree.check()));
            main_pool.reset(); 
        }

        var depth = min_depth;
        while (depth <= max_depth) : (depth += 2) {
            const iterations = @as(i32, @intCast(@as(u32, 1) << @as(u5, @intCast(max_depth - depth + min_depth))));

            var i: i32 = 1;
            while (i <= iterations) : (i += 1) {

                {
                    const tree1 = TreeNode.create(&main_pool, i, depth);
                    self.result_val +%= @as(u32, @bitCast(tree1.check()));
                    main_pool.reset();
                }

                {
                    const tree2 = TreeNode.create(&main_pool, -i, depth);
                    self.result_val +%= @as(u32, @bitCast(tree2.check()));
                    main_pool.reset();
                }
            }
        }
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *Binarytrees = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Binarytrees = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};