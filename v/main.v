module main

import os
import time
import benchmark
import helper
import binarytrees
import pidigits
import brainfuck_array
import brainfuck_recursion
import fannkuchredux
import fasta
import knuckeotide
import regexdna
import revcomp
import spectralnorm
import base64encode
import base64decode
import primes
import noise
import textraytracer
import neuralnet
import mandelbrot
import matmul1t
import matmul_parallel
import nbody
import sorts
import graph_paths
import buffer_hash
import cache_simulation
import calculator
import game_of_life
import mazebench
import compress
import json_benchmarks

fn get_benchmark_factories() []benchmark.BenchmarkInfo {
	return [
		benchmark.BenchmarkInfo{'CLBG::Pidigits', fn () &benchmark.IBenchmark {
			return pidigits.new_pidigits()
		}},
		benchmark.BenchmarkInfo{'Binarytrees::Obj', fn () &benchmark.IBenchmark {
			return binarytrees.new_binarytrees_obj()
		}},
		benchmark.BenchmarkInfo{'Binarytrees::Arena', fn () &benchmark.IBenchmark {
			return binarytrees.new_binarytrees_arena()
		}},
		benchmark.BenchmarkInfo{'CLBG::Fannkuchredux', fn () &benchmark.IBenchmark {
			return fannkuchredux.new_fannkuchredux()
		}},
		benchmark.BenchmarkInfo{'CLBG::Nbody', fn () &benchmark.IBenchmark {
			return nbody.new_nbody()
		}},
		benchmark.BenchmarkInfo{'CLBG::Spectralnorm', fn () &benchmark.IBenchmark {
			return spectralnorm.new_spectralnorm()
		}},
		benchmark.BenchmarkInfo{'Etc::Primes', fn () &benchmark.IBenchmark {
			return primes.new_primes()
		}},
		benchmark.BenchmarkInfo{'Etc::Noise', fn () &benchmark.IBenchmark {
			return noise.new_noise()
		}},
		benchmark.BenchmarkInfo{'CLBG::Mandelbrot', fn () &benchmark.IBenchmark {
			return mandelbrot.new_mandelbrot()
		}},
		benchmark.BenchmarkInfo{'Matmul::T1', fn () &benchmark.IBenchmark {
			return matmul1t.new_matmul1t()
		}},
		benchmark.BenchmarkInfo{'Matmul::T4', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul4t()
		}},
		benchmark.BenchmarkInfo{'Matmul::T8', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul8t()
		}},
		benchmark.BenchmarkInfo{'Matmul::T16', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul16t()
		}},
		benchmark.BenchmarkInfo{'Brainfuck::Array', fn () &benchmark.IBenchmark {
			return brainfuck_array.new_brainfuck_array()
		}},
		benchmark.BenchmarkInfo{'Brainfuck::Recursion', fn () &benchmark.IBenchmark {
			return brainfuck_recursion.new_brainfuck_recursion()
		}},
		benchmark.BenchmarkInfo{'CLBG::Fasta', fn () &benchmark.IBenchmark {
			return fasta.new_fasta()
		}},
		benchmark.BenchmarkInfo{'CLBG::Knuckeotide', fn () &benchmark.IBenchmark {
			return knuckeotide.new_knuckeotide()
		}},
		benchmark.BenchmarkInfo{'CLBG::RegexDna', fn () &benchmark.IBenchmark {
			return regexdna.new_regexdna()
		}},
		benchmark.BenchmarkInfo{'CLBG::Revcomp', fn () &benchmark.IBenchmark {
			return revcomp.new_revcomp()
		}},
		benchmark.BenchmarkInfo{'Base64::Encode', fn () &benchmark.IBenchmark {
			return base64encode.new_base64encode()
		}},
		benchmark.BenchmarkInfo{'Base64::Decode', fn () &benchmark.IBenchmark {
			return base64decode.new_base64decode()
		}},
		benchmark.BenchmarkInfo{'Etc::TextRaytracer', fn () &benchmark.IBenchmark {
			return textraytracer.new_textraytracer()
		}},
		benchmark.BenchmarkInfo{'Json::Generate', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsongenerate()
		}},
		benchmark.BenchmarkInfo{'Json::ParseDom', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsonparsedom()
		}},
		benchmark.BenchmarkInfo{'Json::ParseMapping', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsonparsemapping()
		}},
		benchmark.BenchmarkInfo{'Etc::NeuralNet', fn () &benchmark.IBenchmark {
			return neuralnet.new_neuralnet()
		}},
		benchmark.BenchmarkInfo{'Sort::Quick', fn () &benchmark.IBenchmark {
			return sorts.new_sortquick()
		}},
		benchmark.BenchmarkInfo{'Sort::Merge', fn () &benchmark.IBenchmark {
			return sorts.new_sortmerge()
		}},
		benchmark.BenchmarkInfo{'Sort::Self', fn () &benchmark.IBenchmark {
			return sorts.new_sortself()
		}},
		benchmark.BenchmarkInfo{'Graph::BFS', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathbfs()
		}},
		benchmark.BenchmarkInfo{'Graph::DFS', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathdfs()
		}},
		benchmark.BenchmarkInfo{'Graph::AStar', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathastar()
		}},
		benchmark.BenchmarkInfo{'Hash::SHA256', fn () &benchmark.IBenchmark {
			return buffer_hash.new_bufferhashsha256()
		}},
		benchmark.BenchmarkInfo{'Hash::CRC32', fn () &benchmark.IBenchmark {
			return buffer_hash.new_bufferhashcrc32()
		}},
		benchmark.BenchmarkInfo{'Etc::CacheSimulation', fn () &benchmark.IBenchmark {
			return cache_simulation.new_cachesimulation()
		}},
		benchmark.BenchmarkInfo{'Etc::GameOfLife', fn () &benchmark.IBenchmark {
			return game_of_life.new_gameoflife()
		}},
		benchmark.BenchmarkInfo{'Maze::Generator', fn () &benchmark.IBenchmark {
			return mazebench.new_maze_generator()
		}},
		benchmark.BenchmarkInfo{'Maze::BFS', fn () &benchmark.IBenchmark {
			return mazebench.new_maze_bfs()
		}},
		benchmark.BenchmarkInfo{'Maze::AStar', fn () &benchmark.IBenchmark {
			return mazebench.new_maze_astar()
		}},
		benchmark.BenchmarkInfo{'Calculator::Ast', fn () &benchmark.IBenchmark {
			return calculator.new_calculatorast()
		}},
		benchmark.BenchmarkInfo{'Calculator::Interpreter', fn () &benchmark.IBenchmark {
			return calculator.new_calculatorinterpreter()
		}},
		benchmark.BenchmarkInfo{'Compress::BWTEncode', fn () &benchmark.IBenchmark {
			return compress.new_bwtencode()
		}},
		benchmark.BenchmarkInfo{'Compress::BWTDecode', fn () &benchmark.IBenchmark {
			return compress.new_bwtdecode()
		}},
		benchmark.BenchmarkInfo{'Compress::HuffEncode', fn () &benchmark.IBenchmark {
			return compress.new_huffencode()
		}},
		benchmark.BenchmarkInfo{'Compress::HuffDecode', fn () &benchmark.IBenchmark {
			return compress.new_huffdecode()
		}},
		benchmark.BenchmarkInfo{'Compress::ArithEncode', fn () &benchmark.IBenchmark {
			return compress.new_arithencode()
		}},
		benchmark.BenchmarkInfo{'Compress::ArithDecode', fn () &benchmark.IBenchmark {
			return compress.new_arithdecode()
		}},
		benchmark.BenchmarkInfo{'Compress::LZWEncode', fn () &benchmark.IBenchmark {
			return compress.new_lzwencode()
		}},
		benchmark.BenchmarkInfo{'Compress::LZWDecode', fn () &benchmark.IBenchmark {
			return compress.new_lzwdecode()
		}},
	]
}

fn main() {
	mut config_file := 'test.js'
	mut bench_name := ''

	if os.args.len > 1 {
		config_file = os.args[1]
	}
	if os.args.len > 2 {
		bench_name = os.args[2]
	}

	println('start: ${time.now().unix_milli()}')

	helper.load_config(config_file)

	factories := get_benchmark_factories()
	benchmark.run_benchmarks(factories, bench_name)

	os.write_file('/tmp/recompile_marker', 'RECOMPILE_MARKER_0') or {
		println('Failed to write marker: ${err}')
	}
}
