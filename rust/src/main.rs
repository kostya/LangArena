mod helper;
mod benchmarks;

use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::sync::OnceLock;
use std::time::Instant;
use std::fs;
use serde_json::Value;

static CONFIG: OnceLock<Value> = OnceLock::new();

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

    let mut benchmarks: Vec<Box<dyn Benchmark>> = Vec::new();

    benchmarks.push(Box::new(benchmarks::pidigits::Pidigits::new()));
    benchmarks.push(Box::new(benchmarks::binarytrees::Binarytrees::new()));
    benchmarks.push(Box::new(benchmarks::brainfuck_array::BrainfuckArray::new()));
    benchmarks.push(Box::new(benchmarks::brainfuck_recursion::BrainfuckRecursion::new()));
    benchmarks.push(Box::new(benchmarks::fannkuchredux::Fannkuchredux::new()));
    benchmarks.push(Box::new(benchmarks::fasta::Fasta::new()));
    benchmarks.push(Box::new(benchmarks::knuckeotide::Knuckeotide::new()));
    benchmarks.push(Box::new(benchmarks::mandelbrot::Mandelbrot::new()));
    benchmarks.push(Box::new(benchmarks::matmul1t::Matmul1T::new()));
    benchmarks.push(Box::new(benchmarks::matmul4t::Matmul4T::new()));
    benchmarks.push(Box::new(benchmarks::matmul8t::Matmul8T::new()));
    benchmarks.push(Box::new(benchmarks::matmul16t::Matmul16T::new()));
    benchmarks.push(Box::new(benchmarks::nbody::Nbody::new()));
    benchmarks.push(Box::new(benchmarks::regex_dna::RegexDna::new()));
    benchmarks.push(Box::new(benchmarks::revcomp::Revcomp::new()));
    benchmarks.push(Box::new(benchmarks::spectralnorm::Spectralnorm::new()));
    benchmarks.push(Box::new(benchmarks::base64_encode::Base64Encode::new()));
    benchmarks.push(Box::new(benchmarks::base64_decode::Base64Decode::new()));    
    benchmarks.push(Box::new(benchmarks::json_generate::JsonGenerate::new()));
    benchmarks.push(Box::new(benchmarks::json_parse_dom::JsonParseDom::new()));
    benchmarks.push(Box::new(benchmarks::json_parse_mapping::JsonParseMapping::new()));
    benchmarks.push(Box::new(benchmarks::primes::Primes::new()));
    benchmarks.push(Box::new(benchmarks::noise::Noise::new()));
    benchmarks.push(Box::new(benchmarks::text_raytracer::TextRaytracer::new()));
    benchmarks.push(Box::new(benchmarks::neural_net::NeuralNet::new()));    
    benchmarks.push(Box::new(benchmarks::sort_quick::SortQuick::new()));
    benchmarks.push(Box::new(benchmarks::sort_merge::SortMerge::new()));
    benchmarks.push(Box::new(benchmarks::sort_self::SortSelf::new()));
    benchmarks.push(Box::new(benchmarks::graph_path_bfs::GraphPathBFS::new()));
    benchmarks.push(Box::new(benchmarks::graph_path_dfs::GraphPathDFS::new()));
    benchmarks.push(Box::new(benchmarks::graph_path_dijkstra::GraphPathDijkstra::new()));
    benchmarks.push(Box::new(benchmarks::buffer_hash_sha256::BufferHashSHA256::new()));
    benchmarks.push(Box::new(benchmarks::buffer_hash_crc32::BufferHashCRC32::new()));
    benchmarks.push(Box::new(benchmarks::cache_simulation::CacheSimulation::new()));
    benchmarks.push(Box::new(benchmarks::calculator_ast::CalculatorAst::new()));
    benchmarks.push(Box::new(benchmarks::calculator_interpreter::CalculatorInterpreter::new()));
    benchmarks.push(Box::new(benchmarks::game_of_life::GameOfLife::new()));
    benchmarks.push(Box::new(benchmarks::maze_generator::MazeGenerator::new()));
    benchmarks.push(Box::new(benchmarks::a_star_pathfinder::AStarPathfinder::new()));
    benchmarks.push(Box::new(benchmarks::bwthuff::BWTHuffEncode::new()));
    benchmarks.push(Box::new(benchmarks::bwthuff::BWTHuffDecode::new()));

    let mut results = HashMap::new();
    let mut summary_time = 0.0;
    let mut ok = 0;
    let mut fails = 0;

    for mut bench in benchmarks {
        let name = bench.name();

        if let Some(single) = single_bench {
            let bench_lower = to_lower(&name);
            let search_lower = to_lower(single);
            if !bench_lower.contains(&search_lower) {
                continue;
            }
        }

        if name == "SortBenchmark" || name == "BufferHashBenchmark" || name == "GraphPathBenchmark" {
            continue;
        }

        print!("{}: ", name);

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