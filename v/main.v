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
import compression
import json_benchmarks

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

	mut benchmarks := []&benchmark.IBenchmark{}

	benchmarks << pidigits.new_pidigits()
	benchmarks << binarytrees.new_binarytrees()
	benchmarks << brainfuck_array.new_brainfuck_array()
	benchmarks << brainfuck_recursion.new_brainfuck_recursion()
	benchmarks << fannkuchredux.new_fannkuchredux()
	benchmarks << fasta.new_fasta()
	benchmarks << knuckeotide.new_knuckeotide()
	benchmarks << mandelbrot.new_mandelbrot()
	benchmarks << matmul1t.new_matmul1t()
	benchmarks << matmul_parallel.new_matmul4t()
	benchmarks << matmul_parallel.new_matmul8t()
	benchmarks << matmul_parallel.new_matmul16t()
	benchmarks << nbody.new_nbody()
	benchmarks << regexdna.new_regexdna()
	benchmarks << revcomp.new_revcomp()
	benchmarks << spectralnorm.new_spectralnorm()
	benchmarks << base64encode.new_base64encode()
	benchmarks << base64decode.new_base64decode()
	benchmarks << json_benchmarks.new_jsongenerate()
	benchmarks << json_benchmarks.new_jsonparsedom()
	benchmarks << json_benchmarks.new_jsonparsemapping()
	benchmarks << primes.new_primes()
	benchmarks << noise.new_noise()
	benchmarks << textraytracer.new_textraytracer()
	benchmarks << neuralnet.new_neuralnet()
	benchmarks << sorts.new_sortquick()
	benchmarks << sorts.new_sortmerge()
	benchmarks << sorts.new_sortself()
	benchmarks << graph_paths.new_graphpathbfs()
	benchmarks << graph_paths.new_graphpathdfs()
	benchmarks << graph_paths.new_graphpathastar()
	benchmarks << buffer_hash.new_bufferhashsha256()
	benchmarks << buffer_hash.new_bufferhashcrc32()
	benchmarks << cache_simulation.new_cachesimulation()
	benchmarks << calculator.new_calculatorast()
	benchmarks << calculator.new_calculatorinterpreter()
	benchmarks << game_of_life.new_gameoflife()
	benchmarks << maze_generator.new_mazegenerator()
	benchmarks << astar_pathfinder.new_astarpathfinder()
	benchmarks << compression.new_bwthuffencode()
	benchmarks << compression.new_bwthuffdecode()

	benchmark.run_benchmarks(mut benchmarks, bench_name)

	os.write_file('/tmp/recompile_marker', 'RECOMPILE_MARKER_0') or {
		println('Failed to write marker: ${err}')
	}
}