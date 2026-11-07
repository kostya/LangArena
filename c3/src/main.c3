module app;

import benchmark;
import helper;
import std::io;
import std::io::file;
import std::time;

extern fn Benchmark* binarytrees_obj_create() @cname("BinarytreesObj_create");
extern fn Benchmark* binarytrees_arena_create() @cname("BinarytreesArena_create");
extern fn Benchmark* brainfuck_array_create() @cname("BrainfuckArray_create");
extern fn Benchmark* brainfuck_recursion_create() @cname("BrainfuckRecursion_create");
extern fn Benchmark* fannkuchredux_create() @cname("Fannkuchredux_create");
extern fn Benchmark* mandelbrot_create() @cname("Mandelbrot_create");
extern fn Benchmark* matmul_create() @cname("Matmul_create");
extern fn Benchmark* matmul4t_create() @cname("Matmul4T_create");
extern fn Benchmark* matmul8t_create() @cname("Matmul8T_create");
extern fn Benchmark* matmul16t_create() @cname("Matmul16T_create");
extern fn Benchmark* nbody_create() @cname("Nbody_create");
extern fn Benchmark* spectralnorm_create() @cname("Spectralnorm_create");
extern fn Benchmark* base64_encode_create() @cname("Base64Encode_create");
extern fn Benchmark* base64_decode_create() @cname("Base64Decode_create");
extern fn Benchmark* json_generate_create() @cname("JsonGenerate_create");
extern fn Benchmark* json_parse_dom_create() @cname("JsonParseDom_create");
extern fn Benchmark* json_parse_mapping_create() @cname("JsonParseMapping_create");
extern fn Benchmark* sieve_create() @cname("Sieve_create");
extern fn Benchmark* text_raytracer_create() @cname("TextRaytracer_create");
extern fn Benchmark* neural_net_create() @cname("NeuralNet_create");
extern fn Benchmark* sort_quick_create() @cname("SortQuick_create");
extern fn Benchmark* sort_merge_create() @cname("SortMerge_create");
extern fn Benchmark* sort_self_create() @cname("SortSelf_create");
extern fn Benchmark* graph_path_bfs_create() @cname("GraphPathBFS_create");
extern fn Benchmark* graph_path_dfs_create() @cname("GraphPathDFS_create");
extern fn Benchmark* graph_path_astar_create() @cname("GraphPathAStar_create");
extern fn Benchmark* buffer_hash_sha256_create() @cname("BufferHashSHA256_create");
extern fn Benchmark* buffer_hash_crc32_create() @cname("BufferHashCRC32_create");
extern fn Benchmark* cache_simulation_create() @cname("CacheSimulation_create");
extern fn Benchmark* calculator_ast_create() @cname("CalculatorAst_create");
extern fn Benchmark* calculator_interpreter_create() @cname("CalculatorInterpreter_create");
extern fn Benchmark* game_of_life_create() @cname("GameOfLife_create");
extern fn Benchmark* maze_generator_create() @cname("MazeGenerator_create");
extern fn Benchmark* maze_bfs_create() @cname("MazeBFS_create");
extern fn Benchmark* maze_astar_create() @cname("MazeAStar_create");
extern fn Benchmark* bwt_encode_create() @cname("BWTEncode_create");
extern fn Benchmark* bwt_decode_create() @cname("BWTDecode_create");
extern fn Benchmark* huff_encode_create() @cname("HuffEncode_create");
extern fn Benchmark* huff_decode_create() @cname("HuffDecode_create");
extern fn Benchmark* arith_encode_create() @cname("ArithEncode_create");
extern fn Benchmark* arith_decode_create() @cname("ArithDecode_create");
extern fn Benchmark* lzw_encode_create() @cname("LZWEncode_create");
extern fn Benchmark* lzw_decode_create() @cname("LZWDecode_create");
extern fn Benchmark* jaro_create() @cname("Jaro_create");
extern fn Benchmark* ngram_create() @cname("NGram_create");
extern fn Benchmark* words_create() @cname("Words_create");
extern fn Benchmark* log_parser_create() @cname("LogParser_create");
extern fn Benchmark* template_regex_create() @cname("TemplateRegex_create");
extern fn Benchmark* template_parse_create() @cname("TemplateParse_create");
extern fn Benchmark* csv_parse_create() @cname("CsvParse_create");

fn void register_all_benchmarks()
{
	benchmark::benchmark_register("Binarytrees::Obj", &binarytrees_obj_create);
	benchmark::benchmark_register("Binarytrees::Arena", &binarytrees_arena_create);
	benchmark::benchmark_register("Brainfuck::Array", &brainfuck_array_create);
	benchmark::benchmark_register("Brainfuck::Recursion", &brainfuck_recursion_create);
	benchmark::benchmark_register("CLBG::Fannkuchredux", &fannkuchredux_create);
	benchmark::benchmark_register("CLBG::Mandelbrot", &mandelbrot_create);
	benchmark::benchmark_register("Matmul::Single", &matmul_create);
	benchmark::benchmark_register("Matmul::T4", &matmul4t_create);
	benchmark::benchmark_register("Matmul::T8", &matmul8t_create);
	benchmark::benchmark_register("Matmul::T16", &matmul16t_create);
	benchmark::benchmark_register("CLBG::Nbody", &nbody_create);
	benchmark::benchmark_register("CLBG::Spectralnorm", &spectralnorm_create);
	benchmark::benchmark_register("Base64::Encode", &base64_encode_create);
	benchmark::benchmark_register("Base64::Decode", &base64_decode_create);
	benchmark::benchmark_register("Json::Generate", &json_generate_create);
	benchmark::benchmark_register("Json::ParseDom", &json_parse_dom_create);
	benchmark::benchmark_register("Json::ParseMapping", &json_parse_mapping_create);
	benchmark::benchmark_register("Etc::Sieve", &sieve_create);
	benchmark::benchmark_register("Etc::TextRaytracer", &text_raytracer_create);
	benchmark::benchmark_register("Etc::NeuralNet", &neural_net_create);
	benchmark::benchmark_register("Sort::Quick", &sort_quick_create);
	benchmark::benchmark_register("Sort::Merge", &sort_merge_create);
	benchmark::benchmark_register("Sort::Self", &sort_self_create);
	benchmark::benchmark_register("Graph::BFS", &graph_path_bfs_create);
	benchmark::benchmark_register("Graph::DFS", &graph_path_dfs_create);
	benchmark::benchmark_register("Graph::AStar", &graph_path_astar_create);
	benchmark::benchmark_register("Hash::SHA256", &buffer_hash_sha256_create);
	benchmark::benchmark_register("Hash::CRC32", &buffer_hash_crc32_create);
	benchmark::benchmark_register("Etc::CacheSimulation", &cache_simulation_create);
	benchmark::benchmark_register("Calculator::Ast", &calculator_ast_create);
	benchmark::benchmark_register("Calculator::Interpreter", &calculator_interpreter_create);
	benchmark::benchmark_register("Etc::GameOfLife", &game_of_life_create);
	benchmark::benchmark_register("Maze::Generator", &maze_generator_create);
	benchmark::benchmark_register("Maze::BFS", &maze_bfs_create);
	benchmark::benchmark_register("Maze::AStar", &maze_astar_create);
	benchmark::benchmark_register("Compress::BWTEncode", &bwt_encode_create);
	benchmark::benchmark_register("Compress::BWTDecode", &bwt_decode_create);
	benchmark::benchmark_register("Compress::HuffEncode", &huff_encode_create);
	benchmark::benchmark_register("Compress::HuffDecode", &huff_decode_create);
	benchmark::benchmark_register("Compress::ArithEncode", &arith_encode_create);
	benchmark::benchmark_register("Compress::ArithDecode", &arith_decode_create);
	benchmark::benchmark_register("Compress::LZWEncode", &lzw_encode_create);
	benchmark::benchmark_register("Compress::LZWDecode", &lzw_decode_create);
	benchmark::benchmark_register("Distance::Jaro", &jaro_create);
	benchmark::benchmark_register("Distance::NGram", &ngram_create);
	benchmark::benchmark_register("Etc::Words", &words_create);
	benchmark::benchmark_register("Etc::LogParser", &log_parser_create);
	benchmark::benchmark_register("Template::Regex", &template_regex_create);
	benchmark::benchmark_register("Template::Parse", &template_parse_create);
	benchmark::benchmark_register("CSV::Parse", &csv_parse_create);
}

fn int main(int argc, char** argv)
{
	Time t        = time::now();
	long start_ms = (long)t / (long)time::MS;
	io::printfn("start: %d", start_ms);

	String config_file = argc > 1 ? ((ZString)argv[1]).str_view() : "../run.js";
	(void)helper::helper_load_config(config_file);

	register_all_benchmarks();

	String single_bench = argc > 2 ? ((ZString)argv[2]).str_view() : "";
	benchmark::benchmark_run_all(single_bench);

	helper::helper_free_config();

	if (benchmark::benchmark_factories)
	{
		free(benchmark::benchmark_factories);
		benchmark::benchmark_factories = null;
		benchmark::benchmark_factories_count = 0;
		benchmark::benchmark_factories_capacity = 0;
	}

	String marker = "RECOMPILE_MARKER_0";
	(void)file::save("/tmp/recompile_marker", marker);
	return 0;
}