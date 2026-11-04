from std.time import perf_counter_ns
from std.sys import argv
from std.utils.variant import Variant
from std.builtin.rebind import downcast
from helper import Helper
from benchmark import Benchmark, Config
from binarytrees import BinarytreesObj, BinarytreesArena
from brainfuck_array import BrainfuckArray
from brainfuck_recursion import BrainfuckRecursion
from matmul import MatmulSingle, MatmulT4, MatmulT8, MatmulT16
from base64 import Base64Encode, Base64Decode
from fannkuchredux import Fannkuchredux
from spectralnorm import Spectralnorm
from mandelbrot import Mandelbrot
from nbody import Nbody
from distance import DistanceJaro, DistanceNGram
from maze import MazeGenerator, MazeBFS, MazeAStar
from buffer_hash import HashSHA256, HashCRC32
from graph_path import GraphBFS, GraphDFS, GraphAStar
from sort import SortQuick, SortMerge, SortSelf
from sieve import Sieve
from text_raytracer import TextRaytracer
from neural_net import NeuralNet
from cache_simulation import CacheSimulation
from game_of_life import GameOfLife
from words import Words
from calculator import CalculatorAst, CalculatorInterpreter
from compress import BWTEncode, BWTDecode, HuffEncode, HuffDecode
from compress import ArithEncode, ArithDecode, LZWEncode, LZWDecode
from csv import CsvParse
from log_parser import LogParser
from template import TemplateRegex, TemplateParse
from json_benchmarks import JsonGenerate, JsonParseDom, JsonParseMapping

comptime BenchVariant = Variant[
    BinarytreesObj,
    BinarytreesArena,
    BrainfuckArray,
    BrainfuckRecursion,
    MatmulSingle,
    MatmulT4,
    MatmulT8,
    MatmulT16,
    Base64Encode,
    Base64Decode,
    Fannkuchredux,
    Spectralnorm,
    Mandelbrot,
    Nbody,
    DistanceJaro,
    DistanceNGram,
    MazeGenerator,
    MazeBFS,
    MazeAStar,
    HashSHA256,
    HashCRC32,
    GraphBFS,
    GraphDFS,
    GraphAStar,
    SortQuick,
    SortMerge,
    SortSelf,
    Sieve,
    TextRaytracer,
    NeuralNet,
    CacheSimulation,
    GameOfLife,
    Words,
    CalculatorAst,
    CalculatorInterpreter,
    BWTEncode,
    BWTDecode,
    HuffEncode,
    HuffDecode,
    ArithEncode,
    ArithDecode,
    LZWEncode,
    LZWDecode,
    CsvParse,
    LogParser,
    TemplateRegex,
    TemplateParse,
    JsonGenerate,
    JsonParseDom,
    JsonParseMapping,
]


def create_benchmark(name: String, config: Config) raises -> BenchVariant:
    match name:
        case "Binarytrees::Obj":
            return BenchVariant(BinarytreesObj(config))
        case "Binarytrees::Arena":
            return BenchVariant(BinarytreesArena(config))
        case "Brainfuck::Array":
            return BenchVariant(BrainfuckArray(config))
        case "Brainfuck::Recursion":
            return BenchVariant(BrainfuckRecursion(config))
        case "Matmul::Single":
            return BenchVariant(MatmulSingle(config))
        case "Matmul::T4":
            return BenchVariant(MatmulT4(config))
        case "Matmul::T8":
            return BenchVariant(MatmulT8(config))
        case "Matmul::T16":
            return BenchVariant(MatmulT16(config))
        case "Base64::Encode":
            return BenchVariant(Base64Encode(config))
        case "Base64::Decode":
            return BenchVariant(Base64Decode(config))
        case "CLBG::Fannkuchredux":
            return BenchVariant(Fannkuchredux(config))
        case "CLBG::Spectralnorm":
            return BenchVariant(Spectralnorm(config))
        case "CLBG::Mandelbrot":
            return BenchVariant(Mandelbrot(config))
        case "CLBG::Nbody":
            return BenchVariant(Nbody(config))
        case "Distance::Jaro":
            return BenchVariant(DistanceJaro(config))
        case "Distance::NGram":
            return BenchVariant(DistanceNGram(config))
        case "Maze::Generator":
            return BenchVariant(MazeGenerator(config))
        case "Maze::BFS":
            return BenchVariant(MazeBFS(config))
        case "Maze::AStar":
            return BenchVariant(MazeAStar(config))
        case "Hash::SHA256":
            return BenchVariant(HashSHA256(config))
        case "Hash::CRC32":
            return BenchVariant(HashCRC32(config))
        case "Graph::BFS":
            return BenchVariant(GraphBFS(config))
        case "Graph::DFS":
            return BenchVariant(GraphDFS(config))
        case "Graph::AStar":
            return BenchVariant(GraphAStar(config))
        case "Sort::Quick":
            return BenchVariant(SortQuick(config))
        case "Sort::Merge":
            return BenchVariant(SortMerge(config))
        case "Sort::Self":
            return BenchVariant(SortSelf(config))
        case "Etc::Sieve":
            return BenchVariant(Sieve(config))
        case "Etc::TextRaytracer":
            return BenchVariant(TextRaytracer(config))
        case "Etc::NeuralNet":
            return BenchVariant(NeuralNet(config))
        case "Etc::CacheSimulation":
            return BenchVariant(CacheSimulation(config))
        case "Etc::GameOfLife":
            return BenchVariant(GameOfLife(config))
        case "Etc::Words":
            return BenchVariant(Words(config))
        case "Calculator::Ast":
            return BenchVariant(CalculatorAst(config))
        case "Calculator::Interpreter":
            return BenchVariant(CalculatorInterpreter(config))
        case "Compress::BWTEncode":
            return BenchVariant(BWTEncode(config))
        case "Compress::BWTDecode":
            return BenchVariant(BWTDecode(config))
        case "Compress::HuffEncode":
            return BenchVariant(HuffEncode(config))
        case "Compress::HuffDecode":
            return BenchVariant(HuffDecode(config))
        case "Compress::ArithEncode":
            return BenchVariant(ArithEncode(config))
        case "Compress::ArithDecode":
            return BenchVariant(ArithDecode(config))
        case "Compress::LZWEncode":
            return BenchVariant(LZWEncode(config))
        case "Compress::LZWDecode":
            return BenchVariant(LZWDecode(config))
        case "CSV::Parse":
            return BenchVariant(CsvParse(config))
        case "Etc::LogParser":
            return BenchVariant(LogParser(config))
        case "Template::Regex":
            return BenchVariant(TemplateRegex(config))
        case "Template::Parse":
            return BenchVariant(TemplateParse(config))
        case "Json::Generate":
            return BenchVariant(JsonGenerate(config))
        case "Json::ParseDom":
            return BenchVariant(JsonParseDom(config))
        case "Json::ParseMapping":
            return BenchVariant(JsonParseMapping(config))
        case _:
            raise Error(String(t"Unknown benchmark: {name}"))


def dispatch_bench(
    mut bench: BenchVariant,
    name: String,
    config: Config,
    mut helper: Helper,
    mut summary_time: Float64,
    mut ok: Int,
    mut fails: Int,
) raises:
    comptime for i in range(BenchVariant.Ts.length):
        comptime BenchType = downcast[BenchVariant.Ts[i], Benchmark]
        if bench.isa[BenchType]():
            run_single(
                name, bench[BenchType], config, helper, summary_time, ok, fails
            )
            return


def run_benchmarks(config: Config, single_bench: Optional[String]) raises:
    var summary_time: Float64 = 0.0
    var ok: Int = 0
    var fails: Int = 0
    var helper = Helper()

    for i in range(len(config.entries)):
        ref entry = config.entries[i]
        var bench_name = entry.name

        if single_bench:
            var target = single_bench[]
            if target.lower() not in bench_name.lower():
                continue

        var bench = create_benchmark(bench_name, config)
        dispatch_bench(
            bench, bench_name, config, helper, summary_time, ok, fails
        )

    print(
        String(
            "Summary: ",
            summary_time,
            "s, ",
            ok + fails,
            ", ",
            ok,
            ", ",
            fails,
        )
    )
    if fails > 0:
        raise Error("Benchmarks failed")


def run_single[
    BenchType: Benchmark
](
    name: String,
    mut bench: BenchType,
    config: Config,
    mut helper: Helper,
    mut summary_time: Float64,
    mut ok: Int,
    mut fails: Int,
) raises:
    helper.reset()
    bench.prepare(helper)
    var warmup_iters = bench.warmup_iterations(config)
    bench.warmup(warmup_iters, helper)
    helper.reset()

    var iters = bench.iterations(config)
    var t = perf_counter_ns()
    for i in range(iters):
        bench.run(i, helper)
    var time_delta = Float64(perf_counter_ns() - t) / 1_000_000_000.0

    var check = bench.checksum()
    var expect = bench.expected_checksum(config)

    var status: String
    if check == expect:
        status = "OK"
        ok += 1
    else:
        status = String("ERR[actual=", check, ", expected=", expect, "]")
        fails += 1

    print(String(name, ": ", status, " in ", time_delta, "s"))
    summary_time += time_delta


def main() raises:
    var args = argv()
    var argc = len(args)

    var config_path: String
    var single_bench: Optional[String] = Optional[String](None)

    if argc > 1:
        config_path = String(args[1])
    else:
        config_path = "./test.js"

    if argc > 2:
        single_bench = Optional[String](String(args[2]))

    with open("/tmp/recompile_marker", "w") as f:
        f.write("RECOMPILE_MARKER_0")
    var config = Config(config_path)
    run_benchmarks(config, single_bench)
