const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CalculatorAst = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i32,
    result_val: u64,
    text: []const u8,
    expressions: std.ArrayListUnmanaged(*Node),

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .prepare = prepareImpl,
        .result = resultImpl,
        .deinit = deinitImpl,
    };

    // AST структуры
    pub const Number = struct {
        value: i64,
    };

    pub const Variable = struct {
        name: []const u8,
    };

    pub const BinaryOp = struct {
        op: u8,
        left: *Node,
        right: *Node,
    };

    pub const Assignment = struct {
        var_name: []const u8,
        expr: *Node,
    };

    // Узел AST
    pub const Node = union(enum) {
        number: Number,
        variable: Variable,
        binary_op: *BinaryOp,
        assignment: *Assignment,
    };

    // Парсер
    const Parser = struct {
        allocator: std.mem.Allocator,
        input: []const u8,
        pos: usize = 0,
        current_char: u8 = 0,
        expressions: std.ArrayListUnmanaged(*Node),

        fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
            return Parser{
                .allocator = allocator,
                .input = input,
                .pos = 0,
                .current_char = if (input.len > 0) input[0] else 0,
                .expressions = .{},
            };
        }

        fn advance(self: *Parser) void {
            self.pos += 1;
            if (self.pos >= self.input.len) {
                self.current_char = 0;
            } else {
                self.current_char = self.input[self.pos];
            }
        }

        fn skipWhitespace(self: *Parser) void {
            while (self.current_char != 0 and std.ascii.isWhitespace(self.current_char)) {
                self.advance();
            }
        }

        fn parseNumber(self: *Parser) !*Node {
            var value: i64 = 0;
            while (self.current_char != 0 and std.ascii.isDigit(self.current_char)) {
                value = value * 10 + @as(i64, self.current_char - '0');
                self.advance();
            }
            const node = try self.allocator.create(Node);
            node.* = Node{ .number = Number{ .value = value } };
            return node;
        }

        fn parseVariable(self: *Parser) !*Node {
            const start = self.pos;
            while (self.current_char != 0 and std.ascii.isAlphanumeric(self.current_char)) {
                self.advance();
            }

            const var_name = self.input[start..self.pos];
            const name_copy = try self.allocator.dupe(u8, var_name);

            self.skipWhitespace();
            if (self.current_char == '=') {
                self.advance(); // '='
                const expr = try self.parseExpression();
                const assignment = try self.allocator.create(Assignment);
                assignment.* = Assignment{
                    .var_name = name_copy,
                    .expr = expr,
                };
                const node = try self.allocator.create(Node);
                node.* = Node{ .assignment = assignment };
                return node;
            }

            const node = try self.allocator.create(Node);
            node.* = Node{ .variable = Variable{ .name = name_copy } };
            return node;
        }

        fn parseFactor(self: *Parser) !*Node {
            self.skipWhitespace();
            if (self.current_char == 0) {
                const node = try self.allocator.create(Node);
                node.* = Node{ .number = Number{ .value = 0 } };
                return node;
            }

            if (std.ascii.isDigit(self.current_char)) {
                return try self.parseNumber();
            }

            if (std.ascii.isAlphabetic(self.current_char)) {
                return try self.parseVariable();
            }

            if (self.current_char == '(') {
                self.advance(); // '('
                const node = try self.parseExpression();
                self.skipWhitespace();
                if (self.current_char == ')') {
                    self.advance(); // ')'
                }
                return node;
            }

            const node = try self.allocator.create(Node);
            node.* = Node{ .number = Number{ .value = 0 } };
            return node;
        }

        fn parseTerm(self: *Parser) !*Node {
            var node = try self.parseFactor();

            while (true) {
                self.skipWhitespace();
                if (self.current_char == 0) break;

                if (self.current_char == '*' or self.current_char == '/' or self.current_char == '%') {
                    const op = self.current_char;
                    self.advance();
                    const right = try self.parseFactor();
                    const binary_op = try self.allocator.create(BinaryOp);
                    binary_op.* = BinaryOp{
                        .op = op,
                        .left = node,
                        .right = right,
                    };
                    const new_node = try self.allocator.create(Node);
                    new_node.* = Node{ .binary_op = binary_op };
                    node = new_node;
                } else {
                    break;
                }
            }

            return node;
        }

        fn parseExpression(self: *Parser) anyerror!*Node {
            var node = try self.parseTerm();

            while (true) {
                self.skipWhitespace();
                if (self.current_char == 0) break;

                if (self.current_char == '+' or self.current_char == '-') {
                    const op = self.current_char;
                    self.advance();
                    const right = try self.parseTerm();
                    const binary_op = try self.allocator.create(BinaryOp);
                    binary_op.* = BinaryOp{
                        .op = op,
                        .left = node,
                        .right = right,
                    };
                    const new_node = try self.allocator.create(Node);
                    new_node.* = Node{ .binary_op = binary_op };
                    node = new_node;
                } else {
                    break;
                }
            }

            return node;
        }

        fn parse(self: *Parser) !std.ArrayListUnmanaged(*Node) {
            self.expressions.clearRetainingCapacity();

            while (self.current_char != 0) {
                self.skipWhitespace();
                if (self.current_char == 0) break;

                const expr = try self.parseExpression();
                try self.expressions.append(self.allocator, expr);
            }

            return self.expressions;
        }
    };

    fn generateRandomProgram(allocator: std.mem.Allocator, helper: *Helper, n: i32) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(allocator);

        const writer = buffer.writer(allocator);

        try writer.writeAll("v0 = 1\n");
        for (0..10) |i| {
            const v = i + 1;
            try writer.print("v{} = v{} + {}\n", .{ v, v - 1, v });
        }

        for (0..@as(usize, @intCast(n))) |i| {
            const v = i + 10;
            try writer.print("v{} = v{} + ", .{ v, v - 1 });

            const choice = helper.nextInt(10);
            switch (choice) {
                0 => try writer.print("(v{} / 3) * 4 - {} / (3 + (18 - v{})) % v{} + 2 * ((9 - v{}) * (v{} + 7))", .{ v - 1, i, v - 2, v - 3, v - 6, v - 5 }),
                1 => try writer.print("v{} + (v{} + v{}) * v{} - (v{} / v{})", .{ v - 1, v - 2, v - 3, v - 4, v - 5, v - 6 }),
                2 => try writer.print("(3789 - (((v{})))) + 1", .{v - 7}),
                3 => try writer.print("4/2 * (1-3) + v{}/v{}", .{ v - 9, v - 5 }),
                4 => try writer.print("1+2+3+4+5+6+v{}", .{v - 1}),
                5 => try writer.print("(99999 / v{})", .{v - 3}),
                6 => try writer.print("0 + 0 - v{}", .{v - 8}),
                7 => try writer.print("((((((((((v{})))))))))) * 2", .{v - 6}),
                8 => try writer.print("{} * (v{}%6)%7", .{ i, v - 1 }),
                9 => try writer.print("(1)/(0-v{}) + (v{})", .{ v - 5, v - 7 }),
                else => unreachable,
            }
            try writer.writeAll("\n");
        }

        return buffer.toOwnedSlice(allocator);
    }

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CalculatorAst {
        const n = helper.getInputInt("CalculatorAst");

        const self = try allocator.create(CalculatorAst);
        errdefer allocator.destroy(self);

        self.* = CalculatorAst{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
            .text = "",
            .expressions = .{},
        };

        return self;
    }

    pub fn deinit(self: *CalculatorAst) void {
        const allocator = self.allocator;

        // Освобождаем выражения
        for (self.expressions.items) |expr| {
            freeNode(allocator, expr);
        }
        self.expressions.deinit(allocator);

        if (self.text.len > 0) {
            allocator.free(self.text);
        }

        allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CalculatorAst) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    // Публичные методы для CalculatorInterpreter
    pub fn prepare(self: *CalculatorAst) void {
        prepareImpl(self);
    }

    pub fn run(self: *CalculatorAst) void {
        runImpl(self);
    }

    pub fn getExpressions(self: *CalculatorAst) []*Node {
        return self.expressions.items;
    }

    // Передает владение AST CalculatorInterpreter
    pub fn takeExpressions(self: *CalculatorAst) std.ArrayListUnmanaged(*Node) {
        const result = self.expressions;
        self.expressions = .{}; // Обнуляем, чтобы не освобождалось дважды
        return result;
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Освобождаем старый текст
        if (self.text.len > 0) {
            allocator.free(self.text);
            self.text = "";
        }

        // Генерируем новый текст программы
        self.text = generateRandomProgram(allocator, self.helper, self.n) catch "";
    }

    fn runImpl(ptr: *anyopaque) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        // Очищаем старые выражения
        for (self.expressions.items) |expr| {
            freeNode(allocator, expr);
        }
        self.expressions.clearAndFree(allocator);

        // Парсим прямо в основной аллокатор (без временной arena)
        var parser = Parser.init(allocator, self.text);
        self.expressions = parser.parse() catch return;

        self.result_val = self.expressions.items.len;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        return @as(u32, @truncate(self.result_val));
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
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
