const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const CalculatorAst = @import("calculator_ast.zig").CalculatorAst;

pub const CalculatorInterpreter = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    operations: i64,
    result_val: u32,
    ast_expressions: std.ArrayListUnmanaged(*CalculatorAst.Node),

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    // Интерпретатор
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

        fn evaluate(self: *Interpreter, node: *CalculatorAst.Node) i64 {
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

        fn run(self: *Interpreter, ast_exprs: []*CalculatorAst.Node) i64 {
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
            .helper = helper,
            .operations = operations,
            .result_val = 0,
            .ast_expressions = .{},
        };

        return self;
    }

    pub fn deinit(self: *CalculatorInterpreter) void {
        const allocator = self.allocator;

        // Освобождаем AST выражения
        for (self.ast_expressions.items) |expr| {
            freeNode(allocator, expr);
        }
        self.ast_expressions.deinit(allocator);

        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CalculatorInterpreter) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CalculatorInterpreter");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));

        // Освобождаем старые AST выражения
        for (self.ast_expressions.items) |expr| {
            freeNode(self.allocator, expr);
        }
        self.ast_expressions.clearAndFree(self.allocator);

        // Создаем CalculatorAst для парсинга
        var ast_calculator = CalculatorAst.init(self.allocator, self.helper) catch return;
        defer ast_calculator.deinit();

        // Устанавливаем operations как в C++ версии
        ast_calculator.operations = self.operations;

        // Подготавливаем и запускаем парсинг
        var benchmark = ast_calculator.asBenchmark();
        benchmark.prepare();
        benchmark.run(0);

        // В C++: ast.swap(const_cast<std::vector<CalculatorAst::Node>&>(ca.expressions));
        // В Zig: просто перемещаем владение списком
        self.ast_expressions = ast_calculator.expressions;

        // Очищаем expressions в ast_calculator чтобы избежать двойного освобождения
        ast_calculator.expressions = .{};
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CalculatorInterpreter = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        const allocator = self.allocator;
        const expressions = self.ast_expressions.items;

        var interpreter = Interpreter.init(allocator);
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

// Функция для освобождения узла AST
fn freeNode(allocator: std.mem.Allocator, node: *CalculatorAst.Node) void {
    switch (node.*) {
        .number => {},
        .variable => |*var1| allocator.free(var1.name),
        .binary_op => |binop| {
            freeNode(allocator, binop.left);
            freeNode(allocator, binop.right);
            allocator.destroy(binop);
        },
        .assignment => |ass| {
            allocator.free(ass.var_name);
            freeNode(allocator, ass.expr);
            allocator.destroy(ass);
        },
    }
    allocator.destroy(node);
}