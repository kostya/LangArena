module matmul_parallel

import benchmark
import helper
import sync

pub struct MatmulParallel {
	benchmark.BaseBenchmark
	n           i64
	num_threads int
mut:
	result_val u32
}

pub fn new_matmul4t() &benchmark.IBenchmark {
	mut bench := &MatmulParallel{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T4')
		n:             helper.config_i64('Matmul::T4', 'n')
		num_threads:   4
		result_val:    0
	}
	return bench
}

pub fn new_matmul8t() &benchmark.IBenchmark {
	mut bench := &MatmulParallel{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T8')
		n:             helper.config_i64('Matmul::T8', 'n')
		num_threads:   8
		result_val:    0
	}
	return bench
}

pub fn new_matmul16t() &benchmark.IBenchmark {
	mut bench := &MatmulParallel{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T16')
		n:             helper.config_i64('Matmul::T16', 'n')
		num_threads:   16
		result_val:    0
	}
	return bench
}

pub fn (b MatmulParallel) name() string {
	match b.num_threads {
		4 { return 'Matmul::T4' }
		8 { return 'Matmul::T8' }
		16 { return 'Matmul::T16' }
		else { return 'MatmulParallel' }
	}
}

fn matgen(n int) [][]f64 {
	tmp := 1.0 / f64(n) / f64(n)
	mut a := [][]f64{len: n}

	for i in 0 .. n {
		mut row := []f64{len: n}
		for j in 0 .. n {
			row[j] = tmp * f64(i - j) * f64(i + j)
		}
		a[i] = row
	}

	return a
}

struct Task {
	thread_id   int
	num_threads int
	size        int
	a           [][]f64
	b_t         [][]f64
mut:
	c [][]f64
}

fn process_rows(mut task Task) {
	size := task.size
	num_threads := task.num_threads
	thread_id := task.thread_id

	mut chunk_size := size / num_threads
	if chunk_size == 0 {
		chunk_size = 1
	}

	start_row := thread_id * chunk_size
	mut end_row := start_row + chunk_size
	if thread_id == num_threads - 1 || end_row > size {
		end_row = size
	}

	for i in start_row .. end_row {
		ai := task.a[i]
		mut ci := task.c[i]

		for j in 0 .. size {
			b_tj := task.b_t[j]
			mut sum := 0.0

			for k in 0 .. size {
				sum += ai[k] * b_tj[k]
			}

			ci[j] = sum
		}
	}
}

fn matmul_parallel_impl(a [][]f64, b [][]f64, num_threads int) [][]f64 {
	size := a.len

	mut b_t := [][]f64{len: size}
	for j in 0 .. size {
		mut row := []f64{len: size}
		for i in 0 .. size {
			row[i] = b[i][j]
		}
		b_t[j] = row
	}

	mut c := [][]f64{len: size}
	for i in 0 .. size {
		c[i] = []f64{len: size}
	}

	mut wg := sync.new_waitgroup()

	for thread_id in 0 .. num_threads {
		wg.add(1)

		go fn (thread_id int, num_threads int, size int, a [][]f64, b_t [][]f64, mut c [][]f64, mut wg sync.WaitGroup) {
			defer {
				wg.done()
			}

			mut chunk_size := size / num_threads
			if chunk_size == 0 {
				chunk_size = 1
			}

			start_row := thread_id * chunk_size
			mut end_row := start_row + chunk_size
			if thread_id == num_threads - 1 || end_row > size {
				end_row = size
			}

			for i in start_row .. end_row {
				ai := a[i]
				mut ci := c[i]

				for j in 0 .. size {
					b_tj := b_t[j]
					mut sum := 0.0

					for k in 0 .. size {
						sum += ai[k] * b_tj[k]
					}

					ci[j] = sum
				}
			}
		}(thread_id, num_threads, size, a, b_t, mut c, mut wg)
	}

	wg.wait()

	return c
}

pub fn (mut m MatmulParallel) run(iteration_id int) {
	n := int(m.n)

	a := matgen(n)
	b := matgen(n)

	c := matmul_parallel_impl(a, b, m.num_threads)

	center := c[n >> 1][n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m MatmulParallel) checksum() u32 {
	return m.result_val
}

pub fn (mut m MatmulParallel) prepare() {
	m.result_val = 0
}
