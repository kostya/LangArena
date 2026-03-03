module benchmark

import os
import time
import helper
import json

pub interface IBenchmark {
mut:
	name() string
	run(iteration_id int)
	checksum() u32
	prepare()
	warmup(mut bench IBenchmark)
	warmup_iterations() i64
	iterations() i64
	expected_checksum() i64
}

pub struct BenchmarkInfo {
pub:
	name    string
	creator ?fn () &IBenchmark
}

fn warmup(mut bench IBenchmark) {
	bench.warmup(mut bench)
}

pub fn run_benchmarks(factories []BenchmarkInfo, single_bench string) {
	mut summary_time := 0.0
	mut ok := 0
	mut fails := 0

	mut factory_map := map[string]fn () &IBenchmark{}
	for factory in factories {
		if creator := factory.creator {
			factory_map[factory.name] = creator
		}
	}

	for bench_name in helper.get_order() {
		if single_bench != '' && !bench_name.to_lower().contains(single_bench.to_lower()) {
			continue
		}

		creator := factory_map[bench_name] or {
			println('Warning: Benchmark \'${bench_name}\' defined in config but not found in code')
			continue
		}

		print('${bench_name}: ')
		os.flush()

		mut bench := creator()

		helper.reset()
		bench.prepare()
		warmup(mut bench)
		gc_collect()

		helper.reset()

		start := time.now()
		iters := bench.iterations()
		for i in 0 .. iters {
			bench.run(int(i))
		}
		end := time.now()

		duration := f64(end.unix_nano() - start.unix_nano()) / 1_000_000_000.0

		actual := bench.checksum()
		expected := u32(bench.expected_checksum())

		if actual == expected {
			print('OK ')
			ok++
		} else {
			print('ERR[actual=${actual}, expected=${expected}] ')
			fails++
		}

		println('in ${duration:.3f}s')
		summary_time += duration

		gc_collect()
		time.sleep(1 * time.millisecond)
		gc_collect()
	}

	if ok + fails > 0 {
		println('Summary: ${summary_time:.4f}s, ${ok + fails}, ${ok}, ${fails}')
	}

	if fails > 0 {
		exit(1)
	}
}
