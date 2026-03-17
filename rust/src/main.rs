mod benchmarks;
mod helper;

use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::sync::OnceLock;
use std::time::Instant;

static CONFIG: OnceLock<Value> = OnceLock::new();
static ORDER: OnceLock<Vec<String>> = OnceLock::new();

fn load_config() {
    let filename = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "../test.js".to_string());

    #[cfg(target_arch = "wasm32")]
    let file_content = if filename.contains("run.js") {
        include_str!("../../run.js").to_string()
    } else {
        include_str!("../../test.js").to_string()
    };

    #[cfg(not(target_arch = "wasm32"))]
    let file_content = fs::read_to_string(filename).expect("Failed to read config file");

    let config: Value = serde_json::from_str(&file_content).expect("Failed to parse JSON config");

    if let Some(array) = config.as_array() {
        let mut config_map = serde_json::Map::new();
        let mut order = Vec::new();

        for item in array {
            if let Some(name) = item.get("name").and_then(|n| n.as_str()) {
                config_map.insert(name.to_string(), item.clone());
                order.push(name.to_string());
            }
        }

        CONFIG
            .set(serde_json::Value::Object(config_map))
            .expect("Failed to set CONFIG");
        ORDER.set(order).expect("Failed to set ORDER");
    } else {
        CONFIG.set(config).expect("Failed to set CONFIG");
    }
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

    let mut benchmark_map: HashMap<String, Box<dyn Fn() -> Box<dyn Benchmark> + Send + Sync>> =
        HashMap::new();

    benchmark_map.insert(
        "CLBG::Pidigits".to_string(),
        Box::new(|| Box::new(benchmarks::pidigits::Pidigits::new())),
    );
    benchmark_map.insert(
        "Binarytrees::Obj".to_string(),
        Box::new(|| Box::new(benchmarks::binarytrees::BinarytreesObj::new())),
    );
    benchmark_map.insert(
        "Binarytrees::Arena".to_string(),
        Box::new(|| Box::new(benchmarks::binarytrees::BinarytreesArena::new())),
    );
    benchmark_map.insert(
        "Brainfuck::Array".to_string(),
        Box::new(|| Box::new(benchmarks::brainfuck_array::BrainfuckArray::new())),
    );
    benchmark_map.insert(
        "Brainfuck::Recursion".to_string(),
        Box::new(|| Box::new(benchmarks::brainfuck_recursion::BrainfuckRecursion::new())),
    );
    benchmark_map.insert(
        "CLBG::Fannkuchredux".to_string(),
        Box::new(|| Box::new(benchmarks::fannkuchredux::Fannkuchredux::new())),
    );
    benchmark_map.insert(
        "CLBG::Mandelbrot".to_string(),
        Box::new(|| Box::new(benchmarks::mandelbrot::Mandelbrot::new())),
    );
    benchmark_map.insert(
        "Matmul::Single".to_string(),
        Box::new(|| Box::new(benchmarks::matmul::Matmul1T::new())),
    );
    benchmark_map.insert(
        "Matmul::T4".to_string(),
        Box::new(|| Box::new(benchmarks::matmul::Matmul4T::new())),
    );
    benchmark_map.insert(
        "Matmul::T8".to_string(),
        Box::new(|| Box::new(benchmarks::matmul::Matmul8T::new())),
    );
    benchmark_map.insert(
        "Matmul::T16".to_string(),
        Box::new(|| Box::new(benchmarks::matmul::Matmul16T::new())),
    );
    benchmark_map.insert(
        "CLBG::Nbody".to_string(),
        Box::new(|| Box::new(benchmarks::nbody::Nbody::new())),
    );
    benchmark_map.insert(
        "CLBG::Spectralnorm".to_string(),
        Box::new(|| Box::new(benchmarks::spectralnorm::Spectralnorm::new())),
    );
    benchmark_map.insert(
        "Base64::Encode".to_string(),
        Box::new(|| Box::new(benchmarks::base64_encode::Base64Encode::new())),
    );
    benchmark_map.insert(
        "Base64::Decode".to_string(),
        Box::new(|| Box::new(benchmarks::base64_decode::Base64Decode::new())),
    );
    benchmark_map.insert(
        "Json::Generate".to_string(),
        Box::new(|| Box::new(benchmarks::json_generate::JsonGenerate::new())),
    );
    benchmark_map.insert(
        "Json::ParseDom".to_string(),
        Box::new(|| Box::new(benchmarks::json_parse_dom::JsonParseDom::new())),
    );
    benchmark_map.insert(
        "Json::ParseMapping".to_string(),
        Box::new(|| Box::new(benchmarks::json_parse_mapping::JsonParseMapping::new())),
    );
    benchmark_map.insert(
        "Etc::Sieve".to_string(),
        Box::new(|| Box::new(benchmarks::sieve::Sieve::new())),
    );
    benchmark_map.insert(
        "Etc::TextRaytracer".to_string(),
        Box::new(|| Box::new(benchmarks::text_raytracer::TextRaytracer::new())),
    );
    benchmark_map.insert(
        "Etc::NeuralNet".to_string(),
        Box::new(|| Box::new(benchmarks::neural_net::NeuralNet::new())),
    );
    benchmark_map.insert(
        "Sort::Quick".to_string(),
        Box::new(|| Box::new(benchmarks::sort_quick::SortQuick::new())),
    );
    benchmark_map.insert(
        "Sort::Merge".to_string(),
        Box::new(|| Box::new(benchmarks::sort_merge::SortMerge::new())),
    );
    benchmark_map.insert(
        "Sort::Self".to_string(),
        Box::new(|| Box::new(benchmarks::sort_self::SortSelf::new())),
    );
    benchmark_map.insert(
        "Graph::BFS".to_string(),
        Box::new(|| Box::new(benchmarks::graph_path::GraphPathBFS::new())),
    );
    benchmark_map.insert(
        "Graph::DFS".to_string(),
        Box::new(|| Box::new(benchmarks::graph_path::GraphPathDFS::new())),
    );
    benchmark_map.insert(
        "Graph::AStar".to_string(),
        Box::new(|| Box::new(benchmarks::graph_path::GraphPathAStar::new())),
    );
    benchmark_map.insert(
        "Hash::SHA256".to_string(),
        Box::new(|| Box::new(benchmarks::buffer_hash_sha256::BufferHashSHA256::new())),
    );
    benchmark_map.insert(
        "Hash::CRC32".to_string(),
        Box::new(|| Box::new(benchmarks::buffer_hash_crc32::BufferHashCRC32::new())),
    );
    benchmark_map.insert(
        "Etc::CacheSimulation".to_string(),
        Box::new(|| Box::new(benchmarks::cache_simulation::CacheSimulation::new())),
    );
    benchmark_map.insert(
        "Calculator::Ast".to_string(),
        Box::new(|| Box::new(benchmarks::calculator_ast::CalculatorAst::new())),
    );
    benchmark_map.insert(
        "Calculator::Interpreter".to_string(),
        Box::new(|| Box::new(benchmarks::calculator_interpreter::CalculatorInterpreter::new())),
    );
    benchmark_map.insert(
        "Etc::GameOfLife".to_string(),
        Box::new(|| Box::new(benchmarks::game_of_life::GameOfLife::new())),
    );
    benchmark_map.insert(
        "Maze::Generator".to_string(),
        Box::new(|| Box::new(benchmarks::maze::MazeGenerator::new())),
    );
    benchmark_map.insert(
        "Maze::BFS".to_string(),
        Box::new(|| Box::new(benchmarks::maze::MazeBFS::new())),
    );
    benchmark_map.insert(
        "Maze::AStar".to_string(),
        Box::new(|| Box::new(benchmarks::maze::MazeAStar::new())),
    );
    benchmark_map.insert(
        "Compress::BWTEncode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::BWTEncode::new())),
    );
    benchmark_map.insert(
        "Compress::BWTDecode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::BWTDecode::new())),
    );
    benchmark_map.insert(
        "Compress::HuffEncode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::HuffEncode::new())),
    );
    benchmark_map.insert(
        "Compress::HuffDecode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::HuffDecode::new())),
    );
    benchmark_map.insert(
        "Compress::ArithEncode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::ArithEncode::new())),
    );
    benchmark_map.insert(
        "Compress::ArithDecode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::ArithDecode::new())),
    );
    benchmark_map.insert(
        "Compress::LZWEncode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::LZWEncode::new())),
    );
    benchmark_map.insert(
        "Compress::LZWDecode".to_string(),
        Box::new(|| Box::new(benchmarks::compress::LZWDecode::new())),
    );
    benchmark_map.insert(
        "Distance::Jaro".to_string(),
        Box::new(|| Box::new(benchmarks::distance::Jaro::new())),
    );
    benchmark_map.insert(
        "Distance::NGram".to_string(),
        Box::new(|| Box::new(benchmarks::distance::NGram::new())),
    );
    benchmark_map.insert(
        "Etc::Words".to_string(),
        Box::new(|| Box::new(benchmarks::words::Words::new())),
    );
    benchmark_map.insert(
        "Etc::LogParser".to_string(),
        Box::new(|| Box::new(benchmarks::log_parser::LogParser::new())),
    );
    benchmark_map.insert(
        "Template::Regex".to_string(),
        Box::new(|| Box::new(benchmarks::template::TemplateRegex::new())),
    );
    benchmark_map.insert(
        "Template::Parse".to_string(),
        Box::new(|| Box::new(benchmarks::template::TemplateParse::new())),
    );
    benchmark_map.insert(
        "CSV::Parse".to_string(),
        Box::new(|| Box::new(benchmarks::csv_parse::CsvParse::new())),
    );

    let mut summary_time = 0.0;
    let mut ok = 0;
    let mut fails = 0;

    let order = ORDER.get().expect("Order not loaded");

    for name in order {
        if let Some(single) = single_bench {
            let bench_lower = to_lower(name);
            let search_lower = to_lower(single);
            if !bench_lower.contains(&search_lower) {
                continue;
            }
        }

        let creator = benchmark_map.get(name);
        if creator.is_none() {
            println!(
                "Warning: Benchmark '{}' defined in config but not found in code",
                name
            );
            continue;
        }

        print!("{}: ", name);

        let mut bench = (creator.unwrap())();

        helper::reset();
        bench.prepare();

        bench.warmup();

        helper::reset();

        let start = Instant::now();
        bench.run_all();
        let time_delta = start.elapsed().as_secs_f64();

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
