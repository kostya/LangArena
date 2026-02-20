const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const shared = @import("calculator_shared.zig");

pub const CalculatorAst = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    operations: i64,
    result_val: u32,
    text: []const u8,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CalculatorAst {
        const operations = helper.config_i64("CalculatorAst", "operations");

        const self = try allocator.create(CalculatorAst);
        errdefer allocator.destroy(self);

        self.* = CalculatorAst{
            .allocator = allocator,
            .helper = helper,
            .operations = operations,
            .result_val = 0,
            .text = "",
        };

        return self;
    }

    pub fn deinit(self: *CalculatorAst) void {
        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CalculatorAst) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CalculatorAst");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));

        if (self.text.len > 0) {
            self.allocator.free(self.text);
        }

        self.text = shared.generateRandomProgram(self.allocator, self.helper, self.operations) catch {
            self.text = "";
            return;
        };
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const arena_allocator = arena.allocator();

        var expressions: std.ArrayListUnmanaged(*shared.Node) = .{};
        defer expressions.deinit(arena_allocator);

        var parser = shared.Parser.init(arena_allocator, self.text);
        defer parser.deinit();

        while (parser.current_char != 0) {
            parser.skipWhitespace();
            if (parser.current_char == 0) break;

            const expr = parser.parseExpression() catch {
                return;
            };

            expressions.append(arena_allocator, expr) catch {
                return;
            };

            parser.skipWhitespace();
            if (parser.current_char == '\n' or parser.current_char == ';') {
                parser.advance();
            }
        }

        self.result_val +%= @as(u32, @intCast(expressions.items.len));

        if (expressions.items.len > 0) {
            const last_expr = expressions.items[expressions.items.len - 1];
            if (last_expr.* == .assignment) {
                const assignment = last_expr.assignment;
                self.result_val +%= self.helper.checksumString(assignment.var_name);
            }
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CalculatorAst = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
