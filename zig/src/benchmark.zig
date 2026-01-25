const std = @import("std");
const Helper = @import("helper.zig").Helper;

pub const BenchInfo = struct {
    name: []const u8,
    init_fn: *const fn (std.mem.Allocator, *Helper) anyerror!*anyopaque,
    as_benchmark_fn: *const fn (*anyopaque) Benchmark,
};

pub const Benchmark = struct {
    pub const VTable = struct {
        run: *const fn (self: *anyopaque) void,
        result: *const fn (self: *anyopaque) u32,
        prepare: ?*const fn (self: *anyopaque) void = null,
        deinit: ?*const fn (self: *anyopaque) void = null,
    };

    vtable: *const VTable,
    ptr: *anyopaque,
    helper: *Helper,

    pub fn init(
        self: anytype,
        vtable: *const VTable,
        helper: *Helper,
    ) Benchmark {
        return .{
            .vtable = vtable,
            .ptr = @ptrCast(self),
            .helper = helper,
        };
    }

    pub fn run(self: Benchmark) void {
        self.vtable.run(self.ptr);
    }

    pub fn result(self: Benchmark) u32 {
        return self.vtable.result(self.ptr);
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

// ========== РЕГИСТРАЦИЯ БЕНЧМАРКОВ ==========
pub const all_benchmarks_list = blk: {
    const list = &[_]BenchInfo{
        createBenchInfo("Pidigits", @import("pidigits.zig").Pidigits),
        createBenchInfo("Binarytrees", @import("binarytrees.zig").Binarytrees),
        createBenchInfo("BrainfuckHashMap", @import("brainfuck_hash_map.zig").BrainfuckHashMap),
        createBenchInfo("BrainfuckRecursion", @import("brainfuck_recursion.zig").BrainfuckRecursion),
        createBenchInfo("Fannkuchredux", @import("fannkuchredux.zig").Fannkuchredux),
        createBenchInfo("Fasta", @import("fasta.zig").Fasta),
        createBenchInfo("Knuckeotide", @import("knuckeotide.zig").Knuckeotide),
        createBenchInfo("Mandelbrot", @import("mandelbrot.zig").Mandelbrot),
        createBenchInfo("Matmul", @import("matmul.zig").Matmul),
        createBenchInfo("Matmul4T", @import("matmul4t.zig").Matmul4T),
        createBenchInfo("Matmul8T", @import("matmul8t.zig").Matmul8T),
        createBenchInfo("Matmul16T", @import("matmul16t.zig").Matmul16T),
        createBenchInfo("Nbody", @import("nbody.zig").Nbody),
        createBenchInfo("RegexDna", @import("regex_dna.zig").RegexDna),
        createBenchInfo("Revcomp", @import("revcomp.zig").Revcomp),
        createBenchInfo("Spectralnorm", @import("spectralnorm.zig").Spectralnorm),
        createBenchInfo("Base64Encode", @import("base64encode.zig").Base64Encode),
        createBenchInfo("Base64Decode", @import("base64decode.zig").Base64Decode),
        createBenchInfo("JsonGenerate", @import("json_generate.zig").JsonGenerate),
        createBenchInfo("JsonParseDom", @import("json_parse_dom.zig").JsonParseDom),
        createBenchInfo("JsonParseMapping", @import("json_parse_mapping.zig").JsonParseMapping),
        createBenchInfo("Primes", @import("primes.zig").Primes),
        createBenchInfo("Noise", @import("noise.zig").Noise),
        createBenchInfo("TextRaytracer", @import("text_raytracer.zig").TextRaytracer),
        createBenchInfo("NeuralNet", @import("neural_net.zig").NeuralNet),
        createBenchInfo("SortQuick", @import("sort_quick.zig").SortQuick),
        createBenchInfo("SortMerge", @import("sort_merge.zig").SortMerge),
        createBenchInfo("SortSelf", @import("sort_self.zig").SortSelf),
        createBenchInfo("GraphPathBFS", @import("graph_path_bfs.zig").GraphPathBFS),
        createBenchInfo("GraphPathDFS", @import("graph_path_dfs.zig").GraphPathDFS),
        createBenchInfo("GraphPathDijkstra", @import("graph_path_dijkstra.zig").GraphPathDijkstra),
        createBenchInfo("BufferHashSHA256", @import("buffer_hash_sha256.zig").BufferHashSHA256),
        createBenchInfo("BufferHashCRC32", @import("buffer_hash_crc32.zig").BufferHashCRC32),
        createBenchInfo("CacheSimulation", @import("cache_simulation.zig").CacheSimulation),
        createBenchInfo("CalculatorAst", @import("calculator_ast.zig").CalculatorAst),
        createBenchInfo("CalculatorInterpreter", @import("calculator_interpreter.zig").CalculatorInterpreter),
        createBenchInfo("GameOfLife", @import("game_of_life.zig").GameOfLife),
        createBenchInfo("MazeGenerator", @import("maze_generator.zig").MazeGenerator),
        createBenchInfo("AStarPathfinder", @import("astar_pathfinder.zig").AStarPathfinder),
        createBenchInfo("Compression", @import("compression.zig").Compression),
    };
    break :blk list;
};

pub fn registerBenchmark(
    comptime name: []const u8,
    comptime BenchType: type,
) void {
    // Функция для регистрации (можно использовать если нужно динамическое добавление)
    _ = name;
    _ = BenchType;
    // В текущей реализации просто добавляйте в all_benchmarks_list выше
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

    for (all_benchmarks_list) |bench_info| {
        const bench_name = bench_info.name;

        if (single_bench) |name| {
            if (!std.mem.eql(u8, name, bench_name)) continue;
        }

        std.debug.print("{s}: ", .{bench_name});

        helper.reset();

        const bench_instance = try bench_info.init_fn(allocator, helper);
        defer {
            const temp_bench = bench_info.as_benchmark_fn(bench_instance);
            temp_bench.deinit();
        }

        const benchmark = bench_info.as_benchmark_fn(bench_instance);

        benchmark.prepare();

        var timer = try std.time.Timer.start();
        benchmark.run();
        const time_delta_ns = @as(f64, @floatFromInt(timer.read()));
        const time_delta = time_delta_ns / 1_000_000_000.0;

        try results.put(bench_name, time_delta);

        const actual_result = benchmark.result();
        const expected_result = helper.getExpect(bench_name);

        if (expected_result) |expected| {
            const expected_u32 = @as(u32, @bitCast(@as(i32, @truncate(expected))));

            if (actual_result == expected_u32) {
                std.debug.print("OK ", .{});
                ok += 1;
            } else {
                std.debug.print("ERR[actual={}, expected={}] ", .{ actual_result, expected });
                fails += 1;
            }
        } else {
            std.debug.print("NO_EXPECTED_VALUE ", .{});
        }

        std.debug.print("in {d:.3}s\n", .{time_delta});
        summary_time += time_delta;
    }

    std.debug.print("\nSummary: {d:.4}fs, {}, {}, {}\n", .{
        summary_time,
        ok + fails,
        ok,
        fails,
    });

    if (fails > 0) {
        std.process.exit(1);
    }
}
