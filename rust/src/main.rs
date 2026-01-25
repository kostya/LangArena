mod helper;
mod benchmarks;

use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::sync::OnceLock;
use std::time::Instant;
use std::fs;

// Глобальные структуры для конфигурации
static INPUT: OnceLock<HashMap<String, String>> = OnceLock::new();
static EXPECT: OnceLock<HashMap<String, i64>> = OnceLock::new();

fn load_config() {
    let filename = std::env::args().nth(1).unwrap_or_else(|| "../test.txt".to_string());
    let file = File::open(filename).expect("Failed to open config file");
    
    let mut input_map = HashMap::new();
    let mut expect_map = HashMap::new();
    
    for line in BufReader::new(file).lines() {
        let line = line.expect("Failed to read line");
        if line.trim().is_empty() {
            continue;
        }
        
        let parts: Vec<&str> = line.split('|').collect();
        if parts.len() == 3 {
            let bench_name = parts[0].to_string();
            input_map.insert(bench_name.clone(), parts[1].to_string());
            expect_map.insert(bench_name, parts[2].parse().expect("Failed to parse expected value"));
        }
    }
    
    INPUT.set(input_map).expect("Failed to set INPUT");
    EXPECT.set(expect_map).expect("Failed to set EXPECT");
}

// Базовый trait для бенчмарков
trait Benchmark: Send + Sync {
    fn run(&mut self);
    fn prepare(&mut self) {}
    fn result(&self) -> i64;
    fn iterations(&self) -> i32 {
        INPUT.get()
            .unwrap()
            .get(&self.name())
            .and_then(|s| s.parse().ok())
            .unwrap_or(0)
    }
    fn name(&self) -> String;
}

// Функция для запуска бенчмарков
fn run_benchmarks(single_bench: Option<&str>) {
    load_config();
    helper::reset();
    
    let mut benchmarks: Vec<Box<dyn Benchmark>> = Vec::new();
    
    // Регистрируем бенчмарки
    benchmarks.push(Box::new(benchmarks::pidigits::Pidigits::new()));
    benchmarks.push(Box::new(benchmarks::binarytrees::Binarytrees::new()));
    benchmarks.push(Box::new(benchmarks::brainfuck_hashmap::BrainfuckHashMap::new()));
    benchmarks.push(Box::new(benchmarks::brainfuck_recursion::BrainfuckRecursion::new()));
    benchmarks.push(Box::new(benchmarks::fannkuchredux::Fannkuchredux::new()));
    benchmarks.push(Box::new(benchmarks::fasta::Fasta::new()));
    benchmarks.push(Box::new(benchmarks::knuckeotide::Knuckeotide::new()));
    benchmarks.push(Box::new(benchmarks::mandelbrot::Mandelbrot::new()));
    benchmarks.push(Box::new(benchmarks::matmul::Matmul::new()));
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
    benchmarks.push(Box::new(benchmarks::compression::Compression::new()));
    
    let mut results = HashMap::new();
    let mut summary_time = 0.0;
    let mut ok = 0;
    let mut fails = 0;
    
    for mut bench in benchmarks {
        let name = bench.name();
        
        if let Some(single) = single_bench {
            if single != name {
                continue;
            }
        }
        
        // Пропускаем исключенные бенчмарки (как в Crystal версии)
        if name == "SortBenchmark" || name == "BufferHashBenchmark" || name == "GraphPathBenchmark" {
            continue;
        }
        
        print!("{}: ", name);
        
        helper::reset();
        bench.prepare();
        
        let start = Instant::now();
        bench.run();
        let time_delta = start.elapsed().as_secs_f64();
        
        results.insert(name.clone(), time_delta);
        
        // Симуляция сборки мусора и переключения контекста
        std::thread::yield_now();
        
        let expected = EXPECT.get()
            .unwrap()
            .get(&name)
            .copied()
            .unwrap_or(0);
        
        if bench.result() == expected {
            print!("OK ");
            ok += 1;
        } else {
            print!("ERR[actual={:?}, expected={:?}] ", bench.result(), expected);
            fails += 1;
        }
        
        println!("in {:.3}s", time_delta);
        summary_time += time_delta;
    }
    
    // Сохраняем результаты
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

