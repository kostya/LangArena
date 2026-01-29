const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BrainfuckHashMap = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    text: []const u8,
    result_val: u32,

    const Tape = struct {
        tape: std.ArrayListUnmanaged(u8),
        pos: usize,

        pub fn init(allocator: std.mem.Allocator) !Tape {
            var self = Tape{
                .tape = .{},
                .pos = 0,
            };
            try self.tape.append(allocator, 0);
            return self;
        }

        pub fn deinit(self: *Tape, allocator: std.mem.Allocator) void {
            self.tape.deinit(allocator);
        }

        pub fn get(self: *const Tape) u8 {
            return self.tape.items[self.pos];
        }

        pub fn inc(self: *Tape) void {
            self.tape.items[self.pos] +%= 1;
        }

        pub fn dec(self: *Tape) void {
            self.tape.items[self.pos] -%= 1;
        }

        pub fn advance(self: *Tape, allocator: std.mem.Allocator) void {
            self.pos += 1;
            if (self.pos >= self.tape.items.len) {
                self.tape.append(allocator, 0) catch return;
            }
        }

        pub fn devance(self: *Tape) void {
            if (self.pos > 0) {
                self.pos -= 1;
            }
        }
    };

    const Program = struct {
        chars: std.ArrayListUnmanaged(u8),
        bracket_map: std.AutoHashMap(usize, usize),

        pub fn init(allocator: std.mem.Allocator, text: []const u8) !Program {
            var self = Program{
                .chars = .{},
                .bracket_map = std.AutoHashMap(usize, usize).init(allocator),
            };

            var left_stack = std.ArrayListUnmanaged(usize){};
            defer left_stack.deinit(allocator);

            var pc: usize = 0;

            for (text) |c| {
                if (std.mem.indexOfScalar(u8, "[]<>+-,.", c) != null) {
                    try self.chars.append(allocator, c);
                    if (c == '[') {
                        try left_stack.append(allocator, pc);
                    } else if (c == ']' and left_stack.items.len > 0) {
                        const left = left_stack.pop().?;
                        const right = pc;
                        try self.bracket_map.put(left, right);
                        try self.bracket_map.put(right, left);
                    }
                    pc += 1;
                }
            }

            return self;
        }

        pub fn deinit(self: *Program, allocator: std.mem.Allocator) void {
            self.chars.deinit(allocator);
            self.bracket_map.deinit();
        }

        pub fn run(self: *Program, allocator: std.mem.Allocator) !u32 {
            var result: u32 = 0;
            var tape = try Tape.init(allocator);
            defer tape.deinit(allocator);

            var pc: usize = 0;
            const chars = self.chars.items;

            while (pc < chars.len) {
                const c = chars[pc];
                switch (c) {
                    '+' => tape.inc(),
                    '-' => tape.dec(),
                    '>' => tape.advance(allocator),
                    '<' => tape.devance(),
                    '[' => {
                        if (tape.get() == 0) {
                            pc = self.bracket_map.get(pc).?;
                        }
                    },
                    ']' => {
                        if (tape.get() != 0) {
                            pc = self.bracket_map.get(pc).?;
                        }
                    },
                    '.' => {
                        result = (result << 2) +% tape.get();
                    },
                    else => {},
                }
                pc += 1;
            }

            return result;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
        .warmup = warmupImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BrainfuckHashMap {
        const text = helper.config_s("BrainfuckHashMap", "program");

        const self = try allocator.create(BrainfuckHashMap);
        errdefer allocator.destroy(self);

        self.* = BrainfuckHashMap{
            .allocator = allocator,
            .helper = helper,
            .text = try allocator.dupe(u8, text),
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BrainfuckHashMap) void {
        self.allocator.free(self.text);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BrainfuckHashMap) Benchmark {
        return Benchmark.init(self, &vtable, self.helper);
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BrainfuckHashMap = @ptrCast(@alignCast(ptr));

        var program = Program.init(self.allocator, self.text) catch return;
        defer program.deinit(self.allocator);

        const result = program.run(self.allocator) catch return;
        self.result_val +%= result;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BrainfuckHashMap = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BrainfuckHashMap = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn warmupImpl(ptr: *anyopaque) void {
        const self: *BrainfuckHashMap = @ptrCast(@alignCast(ptr));
        const warmup_program = self.helper.config_s("BrainfuckHashMap", "warmup_program");
        if (warmup_program.len == 0) return;

        var program = Program.init(self.allocator, warmup_program) catch return;
        defer program.deinit(self.allocator);
        _ = program.run(self.allocator) catch return;
    }
};