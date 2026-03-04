module csv_parse

import benchmark
import encoding.csv
import strings
import helper

pub struct CsvParse {
	benchmark.BaseBenchmark
mut:
	result_val u32
	data       string
	rows       int
}

pub fn new_csvparse() &benchmark.IBenchmark {
	mut bench := &CsvParse{
		BaseBenchmark: benchmark.new_base_benchmark('CSV::Parse')
		result_val:    0
		data:          ''
	}
	bench.rows = int(bench.config_i64('rows'))
	return bench
}

pub fn (b CsvParse) name() string {
	return 'CSV::Parse'
}

pub fn (mut b CsvParse) prepare() {
	mut sb := strings.new_builder(100 * b.rows)

	for i in 0 .. b.rows {
		c := u8(`A`) + u8(i % 26)
		x := helper.next_float(1.0)
		z := helper.next_float(1.0)
		y := helper.next_float(1.0)

		sb.write_string('"point ${c:c}\\n, ""${i % 100}""",')
		sb.write_string('${x:.10f},')
		sb.write_string(',')
		sb.write_string('${z:.10f},')
		sb.write_string('"[${if i % 2 == 0 { 'true' } else { 'false' }}\\n, ${i % 100}]",')
		sb.write_string('${y:.10f}\n')
	}

	b.data = sb.str()
}

struct Point {
	x f64
	y f64
	z f64
}

pub fn (mut b CsvParse) run(iteration_id int) {
	if b.data.len == 0 {
		return
	}

	mut points := []Point{}
	mut reader := csv.new_reader(b.data)

	for {
		record := reader.read() or { break }
		x := record[1].f64()
		z := record[3].f64()
		y := record[5].f64()

		points << Point{x, y, z}
	}

	if points.len == 0 {
		return
	}

	mut x_sum := 0.0
	mut y_sum := 0.0
	mut z_sum := 0.0

	for p in points {
		x_sum += p.x
		y_sum += p.y
		z_sum += p.z
	}

	len := points.len
	x_avg := x_sum / f64(len)
	y_avg := y_sum / f64(len)
	z_avg := z_sum / f64(len)

	b.result_val += helper.checksum_f64(x_avg)
	b.result_val += helper.checksum_f64(y_avg)
	b.result_val += helper.checksum_f64(z_avg)
}

pub fn (b CsvParse) checksum() u32 {
	return b.result_val
}
