mod benchmarks;
mod helper;

use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::sync::OnceLock;
use std::time::Instant;

static CONFIG: OnceLock<Value> = OnceLock::new();

struct BenchmarkInfo {
    name: String,
    creator: Box<dyn Fn() -> Box<dyn Benchmark> + Send + Sync>,
}

macro_rules! benchmark_list {
    ($($name:ident: $path:ty),* $(,)?) => {
        vec![
            $(BenchmarkInfo {
                name: stringify!($name).replace("_", "::"),
                creator: Box::new(|| Box::new(<$path>::new())),
            }),*
        ]
    };
}

fn load_config() {
    let filename = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "../test.js".to_string());
    let file_content = fs::read_to_string(filename).expect("Failed to read config file");

    let config: Value = serde_json::from_str(&file_content).expect("Failed to parse JSON config");

    CONFIG.set(config).expect("Failed to set CONFIG");
}

fn config_i64(class_name: &str, field_name: &str) -> i64 {
    let config = CONFIG.get().expect("Config not loaded");
    config
        .get(class_name)
        .and_then(|c| c.get(field_name))
        .and_then(|v| v.as_i64())
        .unwrap_or_else(|| {
            eprintln!("Config not found for {}, field: {}", class_name, field_name);
            0
        })
}

fn config_s(class_name: &str, field_name: &str) -> String {
    let config = CONFIG.get().expect("Config not loaded");
    config
        .get(class_name)
        .and_then(|c| c.get(field_name))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .unwrap_or_else(|| {
            eprintln!("Config not found for {}, field: {}", class_name, field_name);
            String::new()
        })
}

trait Benchmark: Send + Sync {
    fn run(&mut self, iteration_id: i64);
    fn prepare(&mut self) {}
    fn warmup_iterations(&self) -> i64 {
        let config = CONFIG.get().expect("Config not loaded");
        config
            .get(&self.name())
            .and_then(|c| c.get("warmup_iterations"))
            .and_then(|v| v.as_i64())
            .unwrap_or_else(|| {
                let iters = self.iterations();
                std::cmp::max((iters as f64 * 0.2) as i64, 1)
            })
    }

    fn warmup(&mut self) {
        let prepare_iters = self.warmup_iterations();
        for i in 0..prepare_iters {
            self.run(i);
        }
    }

    fn run_all(&mut self) {
        let iters = self.iterations();
        for i in 0..iters {
            self.run(i);
        }
    }

    fn checksum(&self) -> u32;
    fn name(&self) -> String;

    fn config_val(&self, field_name: &str) -> i64 {
        config_i64(&self.name(), field_name)
    }

    fn iterations(&self) -> i64 {
        self.config_val("iterations")
    }

    fn expected_checksum(&self) -> u32 {
        self.config_val("checksum") as u32
    }
}

fn to_lower(s: &str) -> String {
    s.chars().flat_map(char::to_lowercase).collect()
}

fn run_benchmarks(single_bench: Option<&str>) {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis();
    println!("start: {}", now);

    load_config();
    helper::reset();

    let benchmark_factories = benchmark_list![

        CLBG_Pidigits: benchmarks::pidigits::Pidigits,
        CLBG_Fannkuchredux: benchmarks::fannkuchredux::Fannkuchredux,
        CLBG_Fasta: benchmarks::fasta::Fasta,
        CLBG_Knuckeotide: benchmarks::knuckeotide::Knuckeotide,
        CLBG_Mandelbrot: benchmarks::mandelbrot::Mandelbrot,
        CLBG_Nbody: benchmarks::nbody::Nbody,
        CLBG_RegexDna: benchmarks::regex_dna::RegexDna,
        CLBG_Revcomp: benchmarks::revcomp::Revcomp,
        CLBG_Spectralnorm: benchmarks::spectralnorm::Spectralnorm,

        Binarytrees_Obj: benchmarks::binarytrees::BinarytreesObj,
        Binarytrees_Arena: benchmarks::binarytrees::BinarytreesArena,

        Brainfuck_Array: benchmarks::brainfuck_array::BrainfuckArray,
        Brainfuck_Recursion: benchmarks::brainfuck_recursion::BrainfuckRecursion,

        Matmul_Single: benchmarks::matmul::Matmul1T,
        Matmul_T4: benchmarks::matmul::Matmul4T,
        Matmul_T8: benchmarks::matmul::Matmul8T,
        Matmul_T16: benchmarks::matmul::Matmul16T,

        Base64_Encode: benchmarks::base64_encode::Base64Encode,
        Base64_Decode: benchmarks::base64_decode::Base64Decode,

        Json_Generate: benchmarks::json_generate::JsonGenerate,
        Json_ParseDom: benchmarks::json_parse_dom::JsonParseDom,
        Json_ParseMapping: benchmarks::json_parse_mapping::JsonParseMapping,

        Etc_Primes: benchmarks::primes::Primes,
        Etc_Noise: benchmarks::noise::Noise,
        Etc_TextRaytracer: benchmarks::text_raytracer::TextRaytracer,
        Etc_NeuralNet: benchmarks::neural_net::NeuralNet,
        Etc_CacheSimulation: benchmarks::cache_simulation::CacheSimulation,
        Etc_GameOfLife: benchmarks::game_of_life::GameOfLife,

        Sort_Quick: benchmarks::sort_quick::SortQuick,
        Sort_Merge: benchmarks::sort_merge::SortMerge,
        Sort_Self: benchmarks::sort_self::SortSelf,

        Graph_BFS: benchmarks::graph_path::GraphPathBFS,
        Graph_DFS: benchmarks::graph_path::GraphPathDFS,
        Graph_AStar: benchmarks::graph_path::GraphPathAStar,

        Hash_SHA256: benchmarks::buffer_hash_sha256::BufferHashSHA256,
        Hash_CRC32: benchmarks::buffer_hash_crc32::BufferHashCRC32,

        Calculator_Ast: benchmarks::calculator_ast::CalculatorAst,
        Calculator_Interpreter: benchmarks::calculator_interpreter::CalculatorInterpreter,

        Maze_Generator: benchmarks::maze::MazeGenerator,
        Maze_BFS: benchmarks::maze::MazeBFS,
        Maze_AStar: benchmarks::maze::MazeAStar,

        Compress_BWTEncode: benchmarks::compress::BWTEncode,
        Compress_BWTDecode: benchmarks::compress::BWTDecode,
        Compress_HuffEncode: benchmarks::compress::HuffEncode,
        Compress_HuffDecode: benchmarks::compress::HuffDecode,
        Compress_ArithEncode: benchmarks::compress::ArithEncode,
        Compress_ArithDecode: benchmarks::compress::ArithDecode,
        Compress_LZWEncode: benchmarks::compress::LZWEncode,
        Compress_LZWDecode: benchmarks::compress::LZWDecode,
    ];

    let mut results = HashMap::new();
    let mut summary_time = 0.0;
    let mut ok = 0;
    let mut fails = 0;

    for factory in benchmark_factories {
        let name = &factory.name;

        if let Some(single) = single_bench {
            let bench_lower = to_lower(name);
            let search_lower = to_lower(single);
            if !bench_lower.contains(&search_lower) {
                continue;
            }
        }

        if name == "SortBenchmark" || name == "BufferHashBenchmark" || name == "GraphPathBenchmark"
        {
            continue;
        }

        print!("{}: ", name);

        let mut bench = (factory.creator)();

        helper::reset();
        bench.prepare();

        bench.warmup();

        helper::reset();

        let start = Instant::now();
        bench.run_all();
        let time_delta = start.elapsed().as_secs_f64();

        results.insert(name.clone(), time_delta);

        std::thread::yield_now();

        let expected = bench.expected_checksum();

        if bench.checksum() == expected {
            print!("OK ");
            ok += 1;
        } else {
            print!(
                "ERR[actual={:?}, expected={:?}] ",
                bench.checksum(),
                expected
            );
            fails += 1;
        }

        println!("in {:.3}s", time_delta);
        summary_time += time_delta;
    }

    if let Ok(json) = serde_json::to_string(&results) {
        let _ = std::fs::write("/tmp/results.js", json);
    }

    println!(
        "Summary: {:.4}s, {}, {}, {}",
        summary_time,
        ok + fails,
        ok,
        fails
    );

    let _ = fs::write("/tmp/recompile_marker", "RECOMPILE_MARKER_0");

    if fails > 0 {
        std::process::exit(1);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let single_bench = if args.len() > 2 {
        Some(args[2].as_str())
    } else {
        None
    };

    run_benchmarks(single_bench);
}
