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
import maze_generator
import astar_pathfinder
import compress
import json_benchmarks

fn get_benchmark_factories() []benchmark.BenchmarkInfo {
	return [
		benchmark.BenchmarkInfo{'Pidigits', fn () &benchmark.IBenchmark {
			return pidigits.new_pidigits()
		}},
		benchmark.BenchmarkInfo{'BinarytreesObj', fn () &benchmark.IBenchmark {
			return binarytrees.new_binarytrees_obj()
		}},
		benchmark.BenchmarkInfo{'BinarytreesArena', fn () &benchmark.IBenchmark {
			return binarytrees.new_binarytrees_arena()
		}},
		benchmark.BenchmarkInfo{'Fannkuchredux', fn () &benchmark.IBenchmark {
			return fannkuchredux.new_fannkuchredux()
		}},
		benchmark.BenchmarkInfo{'Nbody', fn () &benchmark.IBenchmark {
			return nbody.new_nbody()
		}},
		benchmark.BenchmarkInfo{'Spectralnorm', fn () &benchmark.IBenchmark {
			return spectralnorm.new_spectralnorm()
		}},
		benchmark.BenchmarkInfo{'Primes', fn () &benchmark.IBenchmark {
			return primes.new_primes()
		}},
		benchmark.BenchmarkInfo{'Noise', fn () &benchmark.IBenchmark {
			return noise.new_noise()
		}},
		benchmark.BenchmarkInfo{'Mandelbrot', fn () &benchmark.IBenchmark {
			return mandelbrot.new_mandelbrot()
		}},
		benchmark.BenchmarkInfo{'Matmul1T', fn () &benchmark.IBenchmark {
			return matmul1t.new_matmul1t()
		}},
		benchmark.BenchmarkInfo{'Matmul4T', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul4t()
		}},
		benchmark.BenchmarkInfo{'Matmul8T', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul8t()
		}},
		benchmark.BenchmarkInfo{'Matmul16T', fn () &benchmark.IBenchmark {
			return matmul_parallel.new_matmul16t()
		}},
		benchmark.BenchmarkInfo{'BrainfuckArray', fn () &benchmark.IBenchmark {
			return brainfuck_array.new_brainfuck_array()
		}},
		benchmark.BenchmarkInfo{'BrainfuckRecursion', fn () &benchmark.IBenchmark {
			return brainfuck_recursion.new_brainfuck_recursion()
		}},
		benchmark.BenchmarkInfo{'Fasta', fn () &benchmark.IBenchmark {
			return fasta.new_fasta()
		}},
		benchmark.BenchmarkInfo{'Knuckeotide', fn () &benchmark.IBenchmark {
			return knuckeotide.new_knuckeotide()
		}},
		benchmark.BenchmarkInfo{'RegexDna', fn () &benchmark.IBenchmark {
			return regexdna.new_regexdna()
		}},
		benchmark.BenchmarkInfo{'Revcomp', fn () &benchmark.IBenchmark {
			return revcomp.new_revcomp()
		}},
		benchmark.BenchmarkInfo{'Base64Encode', fn () &benchmark.IBenchmark {
			return base64encode.new_base64encode()
		}},
		benchmark.BenchmarkInfo{'Base64Decode', fn () &benchmark.IBenchmark {
			return base64decode.new_base64decode()
		}},
		benchmark.BenchmarkInfo{'TextRaytracer', fn () &benchmark.IBenchmark {
			return textraytracer.new_textraytracer()
		}},
		benchmark.BenchmarkInfo{'JsonGenerate', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsongenerate()
		}},
		benchmark.BenchmarkInfo{'JsonParseDom', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsonparsedom()
		}},
		benchmark.BenchmarkInfo{'JsonParseMapping', fn () &benchmark.IBenchmark {
			return json_benchmarks.new_jsonparsemapping()
		}},
		benchmark.BenchmarkInfo{'NeuralNet', fn () &benchmark.IBenchmark {
			return neuralnet.new_neuralnet()
		}},
		benchmark.BenchmarkInfo{'SortQuick', fn () &benchmark.IBenchmark {
			return sorts.new_sortquick()
		}},
		benchmark.BenchmarkInfo{'SortMerge', fn () &benchmark.IBenchmark {
			return sorts.new_sortmerge()
		}},
		benchmark.BenchmarkInfo{'SortSelf', fn () &benchmark.IBenchmark {
			return sorts.new_sortself()
		}},
		benchmark.BenchmarkInfo{'GraphPathBFS', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathbfs()
		}},
		benchmark.BenchmarkInfo{'GraphPathDFS', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathdfs()
		}},
		benchmark.BenchmarkInfo{'GraphPathAStar', fn () &benchmark.IBenchmark {
			return graph_paths.new_graphpathastar()
		}},
		benchmark.BenchmarkInfo{'BufferHashSHA256', fn () &benchmark.IBenchmark {
			return buffer_hash.new_bufferhashsha256()
		}},
		benchmark.BenchmarkInfo{'BufferHashCRC32', fn () &benchmark.IBenchmark {
			return buffer_hash.new_bufferhashcrc32()
		}},
		benchmark.BenchmarkInfo{'CacheSimulation', fn () &benchmark.IBenchmark {
			return cache_simulation.new_cachesimulation()
		}},
		benchmark.BenchmarkInfo{'GameOfLife', fn () &benchmark.IBenchmark {
			return game_of_life.new_gameoflife()
		}},
		benchmark.BenchmarkInfo{'MazeGenerator', fn () &benchmark.IBenchmark {
			return maze_generator.new_mazegenerator()
		}},
		benchmark.BenchmarkInfo{'AStarPathfinder', fn () &benchmark.IBenchmark {
			return astar_pathfinder.new_astarpathfinder()
		}},
		benchmark.BenchmarkInfo{'CalculatorAst', fn () &benchmark.IBenchmark {
			return calculator.new_calculatorast()
		}},
		benchmark.BenchmarkInfo{'CalculatorInterpreter', fn () &benchmark.IBenchmark {
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
