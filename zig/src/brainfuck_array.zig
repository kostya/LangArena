const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BrainfuckArray = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    program_text: []const u8,
    warmup_text: []const u8,
    result_val: u32,

    const Tape = struct {
        tape: []u8,
        pos: usize,

        pub fn init(allocator: std.mem.Allocator) !Tape {
            const tape = try allocator.alloc(u8, 30000);
            @memset(tape, 0);
            return Tape{ .tape = tape, .pos = 0 };
        }

        pub fn deinit(self: *Tape, allocator: std.mem.Allocator) void {
            allocator.free(self.tape);
        }

        pub fn get(self: *const Tape) u8 {
            return self.tape[self.pos];
        }

        pub fn inc(self: *Tape) void {
            self.tape[self.pos] +%= 1;
        }

        pub fn dec(self: *Tape) void {
            self.tape[self.pos] -%= 1;
        }

        pub fn advance(self: *Tape, allocator: std.mem.Allocator) !void {
            self.pos += 1;
            if (self.pos >= self.tape.len) {
                const new_len = self.tape.len + 1;
                const new_tape = try allocator.realloc(self.tape, new_len);
                new_tape[self.tape.len] = 0;
                self.tape = new_tape;
            }
        }

        pub fn devance(self: *Tape) void {
            if (self.pos > 0) {
                self.pos -= 1;
            }
        }
    };

    const Program = struct {
        commands: []u8,
        jumps: []usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, text: []const u8) !Program {
            var commands_list = std.ArrayList(u8).initCapacity(allocator, text.len) catch return error.OutOfMemory;
            defer commands_list.deinit(allocator);

            for (text) |c| {
                if (std.mem.indexOfScalar(u8, "[]<>+-,.", c) != null) {
                    commands_list.appendAssumeCapacity(c);
                }
            }

            const commands = try allocator.alloc(u8, commands_list.items.len);
            @memcpy(commands, commands_list.items);

            const jumps = try allocator.alloc(usize, commands.len);
            @memset(jumps, 0);

            var stack = std.ArrayList(usize).initCapacity(allocator, commands.len / 2) catch return error.OutOfMemory;
            defer stack.deinit(allocator);

            for (commands, 0..) |cmd, idx| {
                switch (cmd) {
                    '[' => {
                        stack.appendAssumeCapacity(idx);
                    },
                    ']' => {
                        if (stack.pop()) |start| {
                            jumps[start] = idx;
                            jumps[idx] = start;
                        }
                    },
                    else => {},
                }
            }

            return Program{
                .commands = commands,
                .jumps = jumps,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Program) void {
            self.allocator.free(self.commands);
            self.allocator.free(self.jumps);
        }

        pub fn run(self: *Program) !u32 {
            var result: u32 = 0;
            var tape = try Tape.init(self.allocator);
            defer tape.deinit(self.allocator);

            var pc: usize = 0;
            const commands = self.commands;
            const jumps = self.jumps;

            while (pc < commands.len) {
                const cmd = commands[pc];
                switch (cmd) {
                    '+' => tape.inc(),
                    '-' => tape.dec(),
                    '>' => tape.advance(self.allocator) catch return error.OutOfMemory,
                    '<' => tape.devance(),
                    '[' => {
                        if (tape.get() == 0) {
                            pc = jumps[pc];
                            continue;
                        }
                    },
                    ']' => {
                        if (tape.get() != 0) {
                            pc = jumps[pc];
                            continue;
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

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BrainfuckArray {
        const program_text = helper.config_s("Brainfuck::Array", "program");
        const warmup_text = helper.config_s("Brainfuck::Array", "warmup_program");

        const self = try allocator.create(BrainfuckArray);
        errdefer allocator.destroy(self);

        self.* = BrainfuckArray{
            .allocator = allocator,
            .helper = helper,
            .program_text = try allocator.dupe(u8, program_text),
            .warmup_text = try allocator.dupe(u8, warmup_text),
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BrainfuckArray) void {
        self.allocator.free(self.program_text);
        self.allocator.free(self.warmup_text);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BrainfuckArray) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Brainfuck::Array");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BrainfuckArray = @ptrCast(@alignCast(ptr));

        var program = Program.init(self.allocator, self.program_text) catch return;
        defer program.deinit();

        const result = program.run() catch return;
        self.result_val +%= result;
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BrainfuckArray = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BrainfuckArray = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn warmupImpl(ptr: *anyopaque) void {
        const self: *BrainfuckArray = @ptrCast(@alignCast(ptr));
        if (self.warmup_text.len == 0) return;

        var program = Program.init(self.allocator, self.warmup_text) catch return;
        defer program.deinit();
        _ = program.run() catch return;
    }
};
