module matmul1t

import benchmark
import helper

pub struct Matmul1T {
	benchmark.BaseBenchmark
	n i64
mut:
	result_val u32
}

pub fn new_matmul1t() &benchmark.IBenchmark {
	mut bench := &Matmul1T{
		BaseBenchmark: benchmark.new_base_benchmark('Matmul1T')
		n:             helper.config_i64('Matmul1T', 'n')
		result_val:    0
	}
	return bench
}

pub fn (b Matmul1T) name() string {
	return 'Matmul1T'
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

fn matmul(a [][]f64, b [][]f64) [][]f64 {
	m := a.len
	n := a[0].len
	p := b[0].len

	mut b2 := [][]f64{len: p}
	for j in 0 .. p {
		mut row := []f64{len: n}
		for i in 0 .. n {
			row[i] = b[i][j]
		}
		b2[j] = row
	}

	mut c := [][]f64{len: m}
	for i in 0 .. m {
		ai := a[i]
		mut row := []f64{len: p}

		for j in 0 .. p {
			b2j := b2[j]
			mut s := 0.0

			for k in 0 .. n {
				s += ai[k] * b2j[k]
			}

			row[j] = s
		}

		c[i] = row
	}

	return c
}

pub fn (mut m Matmul1T) run(iteration_id int) {
	_ = iteration_id
	n := int(m.n)

	a := matgen(n)
	b := matgen(n)

	c := matmul(a, b)

	center := c[n >> 1][n >> 1]
	m.result_val += helper.checksum_f64(center)
}

pub fn (m Matmul1T) checksum() u32 {
	return m.result_val
}

pub fn (mut m Matmul1T) prepare() {
	m.result_val = 0
}