module mandelbrot

import benchmark
import helper

pub struct Mandelbrot {
	benchmark.BaseBenchmark
	w i64
	h i64
mut:
	result_bin []u8
}

pub fn new_mandelbrot() &benchmark.IBenchmark {
	mut bench := &Mandelbrot{
		BaseBenchmark: benchmark.new_base_benchmark('Mandelbrot')
		w:             helper.config_i64('Mandelbrot', 'w')
		h:             helper.config_i64('Mandelbrot', 'h')
		result_bin:    []u8{}
	}
	return bench
}

pub fn (b Mandelbrot) name() string {
	return 'Mandelbrot'
}

const iter = 50
const limit = 2.0

pub fn (mut m Mandelbrot) run(iteration_id int) {
	_ = iteration_id
	w := int(m.w)
	h := int(m.h)

	header := 'P4\n${w} ${h}\n'
	m.result_bin << header.bytes()

	mut bit_num := 0
	mut byte_acc := u8(0)
	fw := f64(w)
	fh := f64(h)

	for y in 0 .. h {
		fy := f64(y)
		for x in 0 .. w {
			fx := f64(x)

			cr := 2.0 * fx / fw - 1.5
			ci := 2.0 * fy / fh - 1.0

			mut zr := 0.0
			mut zi := 0.0
			mut tr := 0.0
			mut ti := 0.0
			mut i := 0

			for i < iter && tr + ti <= limit * limit {
				zi = 2.0 * zr * zi + ci
				zr = tr - ti + cr
				tr = zr * zr
				ti = zi * zi
				i++
			}

			byte_acc <<= 1
			if tr + ti <= limit * limit {
				byte_acc |= 0x01
			}
			bit_num++

			if bit_num == 8 {
				m.result_bin << byte_acc
				byte_acc = 0
				bit_num = 0
			} else if x == w - 1 {
				shift := u8(8 - (w % 8))
				byte_acc <<= shift
				m.result_bin << byte_acc
				byte_acc = 0
				bit_num = 0
			}
		}
	}
}

pub fn (m Mandelbrot) checksum() u32 {
	return helper.checksum_bytes(m.result_bin)
}

pub fn (mut m Mandelbrot) prepare() {
	m.result_bin.clear()
}
