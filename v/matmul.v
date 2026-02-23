module matmul

import benchmark
import helper
import sync

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

fn transpose(b [][]f64) [][]f64 {
	n := b.len
	mut b_t := [][]f64{len: n}

	for j in 0 .. n {
		mut row := []f64{len: n}
		for i in 0 .. n {
			row[i] = b[i][j]
		}
		b_t[j] = row
	}

	return b_t
}

fn matmul_sequential(a [][]f64, b [][]f64) [][]f64 {
	n := a.len
	b_t := transpose(b)

	mut c := [][]f64{len: n}
	for i in 0 .. n {
		mut row := []f64{len: n}
		ai := a[i]

		for j in 0 .. n {
			b_tj := b_t[j]
			mut s := 0.0

			for k in 0 .. n {
				s += ai[k] * b_tj[k]
			}

			row[j] = s
		}
		c[i] = row
	}

	return c
}

fn matmul_parallel(a [][]f64, b [][]f64, num_threads int) [][]f64 {
	size := a.len
	b_t := transpose(b)

	mut c := [][]f64{len: size}
	for i in 0 .. size {
		c[i] = []f64{len: size}
	}

	mut wg := sync.new_waitgroup()
	chunk_size := (size + num_threads - 1) / num_threads

	for thread_id in 0 .. num_threads {
		start_row := thread_id * chunk_size
		if start_row >= size {
			break
		}
		mut end_row := start_row + chunk_size
		if end_row > size {
			end_row = size
		}

		wg.add(1)

		spawn fn [a, b_t, mut c, start_row, end_row, size] (mut wg sync.WaitGroup) {
			defer { wg.done() }

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
		}(mut wg)
	}

	wg.wait()
	return c
}

pub struct Matmul1T {
	benchmark.BaseBenchmark
	n int
mut:
	result_val u32
	a          [][]f64
	b          [][]f64
}

pub fn new_matmul1t() &benchmark.IBenchmark {
	n := helper.config_i64('Matmul::Single', 'n')
	mut bench := &Matmul1T{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::Single')
		n:             int(n)
		result_val:    0
	}
	return bench
}

pub fn (b Matmul1T) name() string {
	return 'Matmul::Single'
}

pub fn (mut m Matmul1T) prepare() {
	m.a = matgen(m.n)
	m.b = matgen(m.n)
	m.result_val = 0
}

pub fn (mut m Matmul1T) run(iteration_id int) {
	c := matmul_sequential(m.a, m.b)
	center := c[m.n >> 1][m.n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m Matmul1T) checksum() u32 {
	return m.result_val
}

pub struct Matmul4T {
	benchmark.BaseBenchmark
	n           int
	num_threads int
mut:
	result_val u32
	a          [][]f64
	b          [][]f64
}

pub fn new_matmul4t() &benchmark.IBenchmark {
	n := helper.config_i64('Matmul::T4', 'n')
	mut bench := &Matmul4T{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T4')
		n:             int(n)
		num_threads:   4
		result_val:    0
	}
	return bench
}

pub fn (b Matmul4T) name() string {
	return 'Matmul::T4'
}

pub fn (mut m Matmul4T) prepare() {
	m.a = matgen(m.n)
	m.b = matgen(m.n)
	m.result_val = 0
}

pub fn (mut m Matmul4T) run(iteration_id int) {
	c := matmul_parallel(m.a, m.b, m.num_threads)
	center := c[m.n >> 1][m.n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m Matmul4T) checksum() u32 {
	return m.result_val
}

pub struct Matmul8T {
	benchmark.BaseBenchmark
	n           int
	num_threads int
mut:
	result_val u32
	a          [][]f64
	b          [][]f64
}

pub fn new_matmul8t() &benchmark.IBenchmark {
	n := helper.config_i64('Matmul::T8', 'n')
	mut bench := &Matmul8T{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T8')
		n:             int(n)
		num_threads:   8
		result_val:    0
	}
	return bench
}

pub fn (b Matmul8T) name() string {
	return 'Matmul::T8'
}

pub fn (mut m Matmul8T) prepare() {
	m.a = matgen(m.n)
	m.b = matgen(m.n)
	m.result_val = 0
}

pub fn (mut m Matmul8T) run(iteration_id int) {
	c := matmul_parallel(m.a, m.b, m.num_threads)
	center := c[m.n >> 1][m.n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m Matmul8T) checksum() u32 {
	return m.result_val
}

pub struct Matmul16T {
	benchmark.BaseBenchmark
	n           int
	num_threads int
mut:
	result_val u32
	a          [][]f64
	b          [][]f64
}

pub fn new_matmul16t() &benchmark.IBenchmark {
	n := helper.config_i64('Matmul::T16', 'n')
	mut bench := &Matmul16T{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul::T16')
		n:             int(n)
		num_threads:   16
		result_val:    0
	}
	return bench
}

pub fn (b Matmul16T) name() string {
	return 'Matmul::T16'
}

pub fn (mut m Matmul16T) prepare() {
	m.a = matgen(m.n)
	m.b = matgen(m.n)
	m.result_val = 0
}

pub fn (mut m Matmul16T) run(iteration_id int) {
	c := matmul_parallel(m.a, m.b, m.num_threads)
	center := c[m.n >> 1][m.n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m Matmul16T) checksum() u32 {
	return m.result_val
}
