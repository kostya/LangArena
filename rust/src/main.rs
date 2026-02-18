mod helper;
mod benchmarks;

use std::collections::HashMap;
use std::sync::OnceLock;
use std::time::Instant;
use std::fs;
use serde_json::Value;

static CONFIG: OnceLock<Value> = OnceLock::new();

struct BenchmarkInfo {
    name: String,
    creator: Box<dyn Fn() -> Box<dyn Benchmark> + Send + Sync>,
}

macro_rules! benchmark_list {
    ($($name:ident: $path:ty),* $(,)?) => {
        vec![
            $(BenchmarkInfo {
                name: stringify!($name).to_string(),
                creator: Box::new(|| Box::new(<$path>::new())),
            }),*
        ]
    };
}

fn load_config() {
    let filename = std::env::args().nth(1).unwrap_or_else(|| "../test.js".to_string());
    let file_content = fs::read_to_string(filename).expect("Failed to read config file");

    let config: Value = serde_json::from_str(&file_content)
        .expect("Failed to parse JSON config");

    CONFIG.set(config).expect("Failed to set CONFIG");
}

fn config_i64(class_name: &str, field_name: &str) -> i64 {
    let config = CONFIG.get().expect("Config not loaded");
    config.get(class_name)
        .and_then(|c| c.get(field_name))
        .and_then(|v| v.as_i64())
        .unwrap_or_else(|| {
            eprintln!("Config not found for {}, field: {}", class_name, field_name);
            0
        })
}

fn config_s(class_name: &str, field_name: &str) -> String {
    let config = CONFIG.get().expect("Config not loaded");
    config.get(class_name)
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
        config.get(&self.name())
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
        Pidigits: benchmarks::pidigits::Pidigits,
        Binarytrees: benchmarks::binarytrees::Binarytrees,
        BrainfuckArray: benchmarks::brainfuck_array::BrainfuckArray,
        BrainfuckRecursion: benchmarks::brainfuck_recursion::BrainfuckRecursion,
        Fannkuchredux: benchmarks::fannkuchredux::Fannkuchredux,
        Fasta: benchmarks::fasta::Fasta,
        Knuckeotide: benchmarks::knuckeotide::Knuckeotide,
        Mandelbrot: benchmarks::mandelbrot::Mandelbrot,
        Matmul1T: benchmarks::matmul1t::Matmul1T,
        Matmul4T: benchmarks::matmul4t::Matmul4T,
        Matmul8T: benchmarks::matmul8t::Matmul8T,
        Matmul16T: benchmarks::matmul16t::Matmul16T,
        Nbody: benchmarks::nbody::Nbody,
        RegexDna: benchmarks::regex_dna::RegexDna,
        Revcomp: benchmarks::revcomp::Revcomp,
        Spectralnorm: benchmarks::spectralnorm::Spectralnorm,
        Base64Encode: benchmarks::base64_encode::Base64Encode,
        Base64Decode: benchmarks::base64_decode::Base64Decode,
        JsonGenerate: benchmarks::json_generate::JsonGenerate,
        JsonParseDom: benchmarks::json_parse_dom::JsonParseDom,
        JsonParseMapping: benchmarks::json_parse_mapping::JsonParseMapping,
        Primes: benchmarks::primes::Primes,
        Noise: benchmarks::noise::Noise,
        TextRaytracer: benchmarks::text_raytracer::TextRaytracer,
        NeuralNet: benchmarks::neural_net::NeuralNet,
        SortQuick: benchmarks::sort_quick::SortQuick,
        SortMerge: benchmarks::sort_merge::SortMerge,
        SortSelf: benchmarks::sort_self::SortSelf,
        GraphPathBFS: benchmarks::graph_path::GraphPathBFS,
        GraphPathDFS: benchmarks::graph_path::GraphPathDFS,
        GraphPathAStar: benchmarks::graph_path::GraphPathAStar,
        BufferHashSHA256: benchmarks::buffer_hash_sha256::BufferHashSHA256,
        BufferHashCRC32: benchmarks::buffer_hash_crc32::BufferHashCRC32,
        CacheSimulation: benchmarks::cache_simulation::CacheSimulation,
        CalculatorAst: benchmarks::calculator_ast::CalculatorAst,
        CalculatorInterpreter: benchmarks::calculator_interpreter::CalculatorInterpreter,
        GameOfLife: benchmarks::game_of_life::GameOfLife,
        MazeGenerator: benchmarks::maze_generator::MazeGenerator,
        AStarPathfinder: benchmarks::a_star_pathfinder::AStarPathfinder,
        BWTHuffEncode: benchmarks::bwthuff::BWTHuffEncode,
        BWTHuffDecode: benchmarks::bwthuff::BWTHuffDecode,
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

        if name == "SortBenchmark" || name == "BufferHashBenchmark" || name == "GraphPathBenchmark" {
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
            print!("ERR[actual={:?}, expected={:?}] ", bench.checksum(), expected);
            fails += 1;
        }

        println!("in {:.3}s", time_delta);
        summary_time += time_delta;
    }

    if let Ok(json) = serde_json::to_string(&results) {
        let _ = std::fs::write("/tmp/results.js", json);
    }

    println!("Summary: {:.4}s, {}, {}, {}", summary_time, ok + fails, ok, fails);

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