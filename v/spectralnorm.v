module spectralnorm

import benchmark
import helper
import math

pub struct Spectralnorm {
	benchmark.BaseBenchmark
	size_val i64
mut:
	u []f64
	v []f64
}

pub fn new_spectralnorm() &benchmark.IBenchmark {
	size_val := helper.config_i64('Spectralnorm', 'size')
	mut bench := &Spectralnorm{
		BaseBenchmark: benchmark.new_base_benchmark('Spectralnorm')
		size_val:      size_val
		u:             []f64{len: int(size_val), init: 1.0}
		v:             []f64{len: int(size_val), init: 1.0}
	}
	return bench
}

pub fn (b Spectralnorm) name() string {
	return 'Spectralnorm'
}

fn eval_a(i int, j int) f64 {
	ij := f64(i + j)
	return 1.0 / (ij * (ij + 1.0) / 2.0 + f64(i) + 1.0)
}

fn eval_a_times_u(u []f64) []f64 {
	n := u.len
	mut v := []f64{len: n}

	for i in 0 .. n {
		mut sum := 0.0
		for j, val in u {
			sum += eval_a(i, j) * val
		}
		v[i] = sum
	}

	return v
}

fn eval_at_times_u(u []f64) []f64 {
	n := u.len
	mut v := []f64{len: n}

	for i in 0 .. n {
		mut sum := 0.0
		for j, val in u {
			sum += eval_a(j, i) * val
		}
		v[i] = sum
	}

	return v
}

fn eval_ata_times_u(u []f64) []f64 {

	return eval_at_times_u(eval_a_times_u(u))
}

pub fn (mut s Spectralnorm) run(iteration_id int) {
	_ = iteration_id

	s.v = eval_ata_times_u(s.u)
	s.u = eval_ata_times_u(s.v)
}

pub fn (s Spectralnorm) checksum() u32 {
	mut vbv := 0.0
	mut vv := 0.0
	n := int(s.size_val)

	for i in 0 .. n {
		vbv += s.u[i] * s.v[i]
		vv += s.v[i] * s.v[i]
	}

	result := math.sqrt(vbv / vv)

	return helper.checksum_f64(result)
}

pub fn (mut s Spectralnorm) prepare() {

	n := int(s.size_val)
	s.u = []f64{len: n, init: 1.0}
	s.v = []f64{len: n, init: 1.0}
}