const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const shared = @import("calculator_shared.zig");

pub const CalculatorInterpreter = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator, 
    helper: *Helper,
    operations: i64,
    result_val: u32,
    program: []const u8,
    expressions: std.ArrayListUnmanaged(*shared.Node), 

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    const Interpreter = struct {
        variables: std.StringHashMap(i64),

        fn init(allocator: std.mem.Allocator) Interpreter {
            return Interpreter{
                .variables = std.StringHashMap(i64).init(allocator),
            };
        }

        fn deinit(self: *Interpreter) void {
            self.variables.deinit();
        }

        fn simpleDiv(a: i64, b: i64) i64 {
            if (b == 0) return 0;
            if ((a >= 0 and b > 0) or (a < 0 and b < 0)) {
                return @divTrunc(a, b);
            } else {
                const abs_a = if (a >= 0) a else -a;
                const abs_b = if (b >= 0) b else -b;
                return -@divTrunc(abs_a, abs_b);
            }
        }

        fn simpleMod(a: i64, b: i64) i64 {
            if (b == 0) return 0;
            return a - simpleDiv(a, b) * b;
        }

        fn evaluate(self: *Interpreter, node: *shared.Node) i64 {
            switch (node.*) {
                .number => |num| return num.value,
                .variable => |var1| {
                    return self.variables.get(var1.name) orelse 0;
                },
                .binary_op => |binop| {
                    const left = self.evaluate(binop.left);
                    const right = self.evaluate(binop.right);

                    return switch (binop.op) {
                        '+' => left +% right,
                        '-' => left -% right,
                        '*' => left *% right,
                        '/' => simpleDiv(left, right),
                        '%' => simpleMod(left, right),
                        else => 0,
                    };
                },
                .assignment => |ass| {
                    const value = self.evaluate(ass.expr);
                    _ = self.variables.put(ass.var_name, value) catch 0;
                    return value;
                },
            }
        }

        fn run(self: *Interpreter, ast_exprs: []*shared.Node) i64 {
            var result: i64 = 0;
            for (ast_exprs) |expr| {
                result = self.evaluate(expr);
            }
            return result;
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CalculatorInterpreter {
        const operations = helper.config_i64("CalculatorInterpreter", "operations");

        const self = try allocator.create(CalculatorInterpreter);
        errdefer allocator.destroy(self);

        self.* = CalculatorInterpreter{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator), 
            .helper = helper,
            .operations = operations,
            .result_val = 0,
            .program = "",
            .expressions = .{},
        };

        return self;
    }

    pub fn deinit(self: *CalculatorInterpreter) void {
        self.arena.deinit(); 

        if (self.program.len > 0) {
            self.allocator.free(self.program);
        }

        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CalculatorInterpreter) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CalculatorInterpreter");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));

        if (self.program.len > 0) {
            self.allocator.free(self.program);
        }

        self.program = shared.generateRandomProgram(self.allocator, self.helper, self.operations) catch {
            self.program = "";
            return;
        };

        _ = self.arena.reset(.retain_capacity);
        self.expressions.clearRetainingCapacity();

        const arena_allocator = self.arena.allocator();
        var parser = shared.Parser.init(arena_allocator, self.program);
        defer parser.deinit();

        parser.parse(&self.expressions) catch {
            return;
        };
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const expressions = self.expressions.items;

        var interpreter = Interpreter.init(self.allocator);
        defer interpreter.deinit();

        const result = interpreter.run(expressions);
        self.result_val +%= @as(u32, @intCast(result & 0xFFFFFFFF));
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};