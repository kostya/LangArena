const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const BenchInfo = struct {
    name: []const u8,
    init_fn: *const fn (std.mem.Allocator, *Helper) anyerror!*anyopaque,
    as_benchmark_fn: *const fn (*anyopaque) Benchmark,
};

pub const Benchmark = struct {
    pub const VTable = struct {
        run: *const fn (self: *anyopaque, iteration_id: i64) void,
        checksum: *const fn (self: *anyopaque) u32,
        prepare: ?*const fn (self: *anyopaque) void = null,
        deinit: ?*const fn (self: *anyopaque) void = null,
        warmup: ?*const fn (self: *anyopaque) void = null,
        run_all: ?*const fn (self: *anyopaque) void = null,
        config_val: ?*const fn (self: *anyopaque, field_name: []const u8) i64 = null,
        iterations: ?*const fn (self: *anyopaque) i64 = null,
        expected_checksum: ?*const fn (self: *anyopaque) i64 = null,
        warmup_iterations: ?*const fn (self: *anyopaque) i64 = null,
    };

    name: []const u8,
    vtable: *const VTable,
    ptr: *anyopaque,
    helper: *Helper,

    pub fn init(
        self: anytype,
        vtable: *const VTable,
        helper: *Helper,
        name: []const u8,
    ) Benchmark {
        return .{
            .vtable = vtable,
            .ptr = @ptrCast(self),
            .helper = helper,
            .name = name,
        };
    }

    pub fn run(self: Benchmark, iteration_id: i64) void {
        self.vtable.run(self.ptr, iteration_id);
    }

    pub fn checksum(self: Benchmark) u32 {
        return self.vtable.checksum(self.ptr);
    }

    pub fn prepare(self: Benchmark) void {
        if (self.vtable.prepare) |prepare_fn| {
            prepare_fn(self.ptr);
        }
    }

    pub fn deinit(self: Benchmark) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }

    pub fn warmup(self: Benchmark) void {
        if (self.vtable.warmup) |warmup_fn| {
            warmup_fn(self.ptr);
        } else {
            const warmup_iters = self.warmup_iterations();
            var i: i64 = 0;
            while (i < warmup_iters) : (i += 1) {
                self.run(i);
            }
        }
    }

    pub fn run_all(self: Benchmark) void {
        if (self.vtable.run_all) |run_all_fn| {
            run_all_fn(self.ptr);
        } else {
            const iters = self.iterations();
            var i: i64 = 0;
            while (i < iters) : (i += 1) {
                self.run(i);
            }
        }
    }

    pub fn config_val(self: Benchmark, field_name: []const u8) i64 {
        if (self.vtable.config_val) |config_val_fn| {
            return config_val_fn(self.ptr, field_name);
        }
        return self.helper.config_i64(self.name, field_name);
    }

    pub fn iterations(self: Benchmark) i64 {
        if (self.vtable.iterations) |iterations_fn| {
            return iterations_fn(self.ptr);
        }
        return self.config_val("iterations");
    }

    pub fn expected_checksum(self: Benchmark) i64 {
        if (self.vtable.expected_checksum) |expected_checksum_fn| {
            return expected_checksum_fn(self.ptr);
        }
        return self.config_val("checksum");
    }

    pub fn warmup_iterations(self: Benchmark) i64 {
        if (self.vtable.warmup_iterations) |warmup_iterations_fn| {
            return warmup_iterations_fn(self.ptr);
        } else {
            const iters = self.iterations();
            return @max(@as(i64, @intFromFloat(@as(f64, @floatFromInt(iters)) * 0.2)), 1);
        }
    }
};

pub fn createBenchInfo(
    comptime name: []const u8,
    comptime BenchType: type,
) BenchInfo {
    return BenchInfo{
        .name = name,
        .init_fn = struct {
            fn initFn(allocator: std.mem.Allocator, h: *Helper) !*anyopaque {
                const bench = try BenchType.init(allocator, h);
                return @ptrCast(bench);
            }
        }.initFn,
        .as_benchmark_fn = struct {
            fn asBenchmarkFn(ptr: *anyopaque) Benchmark {
                const bench: *BenchType = @ptrCast(@alignCast(ptr));
                return bench.asBenchmark();
            }
        }.asBenchmarkFn,
    };
}

fn toLower(str: []const u8, buffer: []u8) []const u8 {
    for (str, 0..) |c, i| {
        buffer[i] = std.ascii.toLower(c);
    }
    return buffer[0..str.len];
}

pub const all_benchmarks_list = blk: {
    const list = &[_]BenchInfo{
        createBenchInfo("CLBG::Pidigits", @import("pidigits.zig").Pidigits),
        createBenchInfo("Binarytrees::Obj", @import("binarytrees.zig").BinarytreesObj),
        createBenchInfo("Binarytrees::Arena", @import("binarytrees.zig").BinarytreesArena),
        createBenchInfo("Brainfuck::Array", @import("brainfuck_array.zig").BrainfuckArray),
        createBenchInfo("Brainfuck::Recursion", @import("brainfuck_recursion.zig").BrainfuckRecursion),
        createBenchInfo("CLBG::Fannkuchredux", @import("fannkuchredux.zig").Fannkuchredux),
        createBenchInfo("CLBG::Fasta", @import("fasta.zig").Fasta),
        createBenchInfo("CLBG::Knuckeotide", @import("knuckeotide.zig").Knuckeotide),
        createBenchInfo("CLBG::Mandelbrot", @import("mandelbrot.zig").Mandelbrot),
        createBenchInfo("Matmul::Single", @import("matmul.zig").Matmul1T),
        createBenchInfo("Matmul::T4", @import("matmul.zig").Matmul4T),
        createBenchInfo("Matmul::T8", @import("matmul.zig").Matmul8T),
        createBenchInfo("Matmul::T16", @import("matmul.zig").Matmul16T),
        createBenchInfo("CLBG::Nbody", @import("nbody.zig").Nbody),
        createBenchInfo("CLBG::RegexDna", @import("regex_dna.zig").RegexDna),
        createBenchInfo("CLBG::Revcomp", @import("revcomp.zig").Revcomp),
        createBenchInfo("CLBG::Spectralnorm", @import("spectralnorm.zig").Spectralnorm),
        createBenchInfo("Base64::Encode", @import("base64encode.zig").Base64Encode),
        createBenchInfo("Base64::Decode", @import("base64decode.zig").Base64Decode),
        createBenchInfo("Json::Generate", @import("json_generate.zig").JsonGenerate),
        createBenchInfo("Json::ParseDom", @import("json_parse_dom.zig").JsonParseDom),
        createBenchInfo("Json::ParseMapping", @import("json_parse_mapping.zig").JsonParseMapping),
        createBenchInfo("Etc::Sieve", @import("sieve.zig").Sieve),
        createBenchInfo("Etc::Noise", @import("noise.zig").Noise),
        createBenchInfo("Etc::TextRaytracer", @import("text_raytracer.zig").TextRaytracer),
        createBenchInfo("Etc::NeuralNet", @import("neural_net.zig").NeuralNet),
        createBenchInfo("Sort::Quick", @import("sort_quick.zig").SortQuick),
        createBenchInfo("Sort::Merge", @import("sort_merge.zig").SortMerge),
        createBenchInfo("Sort::Self", @import("sort_self.zig").SortSelf),
        createBenchInfo("Graph::BFS", @import("graph_path.zig").GraphPathBFS),
        createBenchInfo("Graph::DFS", @import("graph_path.zig").GraphPathDFS),
        createBenchInfo("Graph::AStar", @import("graph_path.zig").GraphPathAStar),
        createBenchInfo("Hash::SHA256", @import("buffer_hash_sha256.zig").BufferHashSHA256),
        createBenchInfo("Hash::CRC32", @import("buffer_hash_crc32.zig").BufferHashCRC32),
        createBenchInfo("Etc::CacheSimulation", @import("cache_simulation.zig").CacheSimulation),
        createBenchInfo("Calculator::Ast", @import("calculator_ast.zig").CalculatorAst),
        createBenchInfo("Calculator::Interpreter", @import("calculator_interpreter.zig").CalculatorInterpreter),
        createBenchInfo("Etc::GameOfLife", @import("game_of_life.zig").GameOfLife),
        createBenchInfo("Maze::Generator", @import("maze.zig").MazeGenerator),
        createBenchInfo("Maze::BFS", @import("maze.zig").MazeBFS),
        createBenchInfo("Maze::AStar", @import("maze.zig").MazeAStar),
        createBenchInfo("Compress::BWTEncode", @import("compress.zig").BWTEncode),
        createBenchInfo("Compress::BWTDecode", @import("compress.zig").BWTDecode),
        createBenchInfo("Compress::HuffEncode", @import("compress.zig").HuffEncode),
        createBenchInfo("Compress::HuffDecode", @import("compress.zig").HuffDecode),
        createBenchInfo("Compress::ArithEncode", @import("compress.zig").ArithEncode),
        createBenchInfo("Compress::ArithDecode", @import("compress.zig").ArithDecode),
        createBenchInfo("Compress::LZWEncode", @import("compress.zig").LZWEncode),
        createBenchInfo("Compress::LZWDecode", @import("compress.zig").LZWDecode),
        createBenchInfo("Distance::Jaro", @import("distance.zig").Jaro),
        createBenchInfo("Distance::NGram", @import("distance.zig").NGram),
    };
    break :blk list;
};

pub fn registerBenchmark(
    comptime name: []const u8,
    comptime BenchType: type,
) void {
    _ = name;
    _ = BenchType;
}

pub fn runAllBenchmarks(
    allocator: std.mem.Allocator,
    helper: *Helper,
    single_bench: ?[]const u8,
) !void {
    var results = std.StringHashMap(f64).init(allocator);
    defer results.deinit();

    var summary_time: f64 = 0.0;
    var ok: u32 = 0;
    var fails: u32 = 0;

    var buffer: [1024]u8 = undefined;
    var stdout_wrapper = std.fs.File.stdout().writer(&buffer);
    const stdout = &stdout_wrapper.interface;

    for (all_benchmarks_list) |bench_info| {
        const bench_name = bench_info.name;

        if (single_bench) |name| {
            var name_lower_buf: [256]u8 = undefined;
            var bench_lower_buf: [256]u8 = undefined;

            const name_lower = toLower(name, &name_lower_buf);
            const bench_lower = toLower(bench_name, &bench_lower_buf);

            if (std.mem.indexOf(u8, bench_lower, name_lower) == null) {
                continue;
            }
        }

        std.debug.print("{s}: ", .{bench_name});

        const bench_instance = try bench_info.init_fn(allocator, helper);
        defer {
            const temp_bench = bench_info.as_benchmark_fn(bench_instance);
            temp_bench.deinit();
        }

        const benchmark = bench_info.as_benchmark_fn(bench_instance);

        helper.reset();
        benchmark.prepare();
        benchmark.warmup();

        helper.reset();

        var timer = try std.time.Timer.start();
        benchmark.run_all();
        const time_delta_ns = @as(f64, @floatFromInt(timer.read()));
        const time_delta = time_delta_ns / 1_000_000_000.0;

        try results.put(bench_name, time_delta);

        const actual_checksum = benchmark.checksum();
        const expected_checksum = @as(u32, @intCast(helper.config_i64(bench_name, "checksum")));

        if (actual_checksum == expected_checksum) {
            try stdout.print("OK ", .{});
            try stdout.flush();
            ok += 1;
        } else {
            try stdout.print("ERR[actual={}, expected={}] ", .{ actual_checksum, expected_checksum });
            try stdout.flush();

            fails += 1;
        }

        try stdout.print("in {d:.3}s\n", .{time_delta});
        try stdout.flush();
        summary_time += time_delta;
    }

    try stdout.print("\nSummary: {d:.4}s, {}, {}, {}\n", .{
        summary_time,
        ok + fails,
        ok,
        fails,
    });
    try stdout.flush();

    const results_file = try std.fs.cwd().createFile("/tmp/results.js", .{});
    defer results_file.close();

    var buffer2: [8192]u8 = undefined;
    var fba = std.io.fixedBufferStream(&buffer2);
    var writer = fba.writer();

    try writer.print("{{", .{});

    var first = true;
    var iter = results.iterator();
    while (iter.next()) |entry| {
        if (!first) {
            try writer.writeAll(",");
        }
        first = false;
        try writer.print("\"{s}\":{d:.3}", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    try writer.writeAll("}");
    try writer.writeAll("\n");

    try results_file.writeAll(fba.getWritten());

    if (fails > 0) {
        std.process.exit(1);
    }
}
