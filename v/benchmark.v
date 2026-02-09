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

fn warmup(mut bench IBenchmark) {
	bench.warmup(mut bench)
}

pub fn run_benchmarks(mut benchmarks []&IBenchmark, single_bench string) {
	mut results := map[string]f64{}
	mut summary_time := 0.0
	mut ok := 0
	mut fails := 0

	for mut bench in benchmarks {
		bench_name := bench.name()
		if single_bench != '' && !bench.name().to_lower().contains(single_bench.to_lower()) {
			continue
		}
		print('${bench_name}: ')
		os.flush()

		helper.reset()
		bench.prepare()
		warmup(mut bench)

		helper.reset()

		start := time.now()
		iters := bench.iterations()
		for i in 0 .. iters {
			bench.run(int(i))
		}
		end := time.now()

		duration := f64(end.unix_nano() - start.unix_nano()) / 1_000_000_000.0
		results[bench_name] = duration

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

		time.sleep(1 * time.millisecond)
	}

	save_results(results)

	if ok + fails > 0 {
		println('Summary: ${summary_time:.4f}s, ${ok + fails}, ${ok}, ${fails}')
	}

	if fails > 0 {
		exit(1)
	}
}

fn save_results(results map[string]f64) {
	json_str := json.encode(results)
	os.write_file('/tmp/results.js', json_str) or {}
}