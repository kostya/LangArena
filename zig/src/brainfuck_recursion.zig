const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BrainfuckRecursion = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: i64,

    const OpType = enum { inc, move, loop, print };

    const Op = struct {
        op_type: OpType,
        val: i32 = 0,
        loop: []const Op = &.{}, // slice вместо ArrayList
    };

    const Tape = struct {
        data: []u8, // slice с управлением capacity
        pos: usize = 0,

        fn init(allocator: std.mem.Allocator) !Tape {
            const initial_size = 65536; // 64KB предварительно
            const data = try allocator.alloc(u8, initial_size);
            @memset(data, 0);
            return Tape{ .data = data };
        }

        fn deinit(self: *Tape, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }

        inline fn get(self: *const Tape) u8 {
            return self.data[self.pos];
        }

        inline fn inc(self: *Tape, x: i32) void {
            const current = self.data[self.pos];
            const new_val = @as(i32, current) + x;
            self.data[self.pos] = @as(u8, @intCast(new_val & 0xFF));
        }

        fn move(self: *Tape, allocator: std.mem.Allocator, x: i32) void {
            if (x >= 0) {
                const new_pos = self.pos + @as(usize, @intCast(x));
                if (new_pos >= self.data.len) {
                    // Увеличиваем размер в 2 раза или до нужного
                    const new_len = @max(self.data.len * 2, new_pos + 1);
                    const new_data = allocator.realloc(self.data, new_len) catch return;
                    // Обнуляем новую часть
                    @memset(new_data[self.data.len..], 0);
                    self.data = new_data;
                }
                self.pos = new_pos;
            } else {
                const move_left = @as(usize, @intCast(-x));
                if (move_left > self.pos) {
                    self.pos = 0; // Ограничиваем слева
                } else {
                    self.pos -= move_left;
                }
            }
        }
    };

    const Program = struct {
        ops: []const Op,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, text: []const u8) !Program {
            var iter = StrIterator.init(text);
            const ops = try parse(allocator, &iter);
            return Program{
                .ops = ops,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Program) void {
            deinitOps(self.ops, self.allocator);
            self.allocator.free(self.ops);
        }

        fn run(self: *Program) !i64 {
            var tape = try Tape.init(self.allocator);
            defer tape.deinit(self.allocator);

            var result: i64 = 0;
            self.runOps(self.ops, &tape, &result);
            return result;
        }

        fn runOps(self: *Program, ops: []const Op, tape: *Tape, result: *i64) void {
            for (ops) |op| {
                switch (op.op_type) {
                    .inc => tape.inc(op.val),
                    .move => tape.move(self.allocator, op.val),
                    .loop => {
                        while (tape.get() != 0) {
                            self.runOps(op.loop, tape, result);
                        }
                    },
                    .print => {
                        result.* = (result.* << 2) + tape.get();
                    },
                }
            }
        }
    };

    const StrIterator = struct {
        text: []const u8,
        pos: usize = 0,

        fn init(text: []const u8) StrIterator {
            return StrIterator{ .text = text };
        }

        inline fn next(self: *StrIterator) ?u8 {
            if (self.pos < self.text.len) {
                const c = self.text[self.pos];
                self.pos += 1;
                return c;
            }
            return null;
        }
    };

    fn parse(allocator: std.mem.Allocator, iter: *StrIterator) ![]const Op {
        var ops = std.ArrayListUnmanaged(Op){};
        defer ops.deinit(allocator);

        try ops.ensureTotalCapacity(allocator, 256);

        while (iter.next()) |c| {
            switch (c) {
                '+' => try ops.append(allocator, .{ .op_type = .inc, .val = 1 }),
                '-' => try ops.append(allocator, .{ .op_type = .inc, .val = -1 }),
                '>' => try ops.append(allocator, .{ .op_type = .move, .val = 1 }),
                '<' => try ops.append(allocator, .{ .op_type = .move, .val = -1 }),
                '.' => try ops.append(allocator, .{ .op_type = .print }),
                '[' => {
                    const loop_ops = try parse(allocator, iter);
                    try ops.append(allocator, .{ .op_type = .loop, .loop = loop_ops });
                },
                ']' => {
                    const result = try ops.toOwnedSlice(allocator);
                    return result;
                },
                else => continue,
            }
        }

        const result = try ops.toOwnedSlice(allocator);
        return result;
    }

    fn deinitOps(ops: []const Op, allocator: std.mem.Allocator) void {
        for (ops) |op| {
            if (op.op_type == .loop) {
                deinitOps(op.loop, allocator);
                allocator.free(op.loop);
            }
        }
    }

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BrainfuckRecursion {
        const text = helper.getInput("BrainfuckRecursion") orelse "";

        const self = try allocator.create(BrainfuckRecursion);
        errdefer allocator.destroy(self);

        self.* = BrainfuckRecursion{
            .allocator = allocator,
            .helper = helper,
            .text = try allocator.dupe(u8, text),
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BrainfuckRecursion) void {
        self.allocator.free(self.text);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BrainfuckRecursion) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *BrainfuckRecursion = @ptrCast(@alignCast(ptr));

        var program = Program.init(self.allocator, self.text) catch return;
        defer program.deinit();

        self.result_val = program.run() catch return;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BrainfuckRecursion = @ptrCast(@alignCast(ptr));
        return @as(u32, @bitCast(@as(i32, @truncate(self.result_val))));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BrainfuckRecursion = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
