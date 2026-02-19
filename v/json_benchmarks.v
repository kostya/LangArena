module json_benchmarks

import benchmark
import helper
import json
import x.json2
import math

type OptsType = int | bool

pub struct JsonGenerate {
	benchmark.BaseBenchmark
mut:
	result_val u32
	n          i64
	text       string
	data       CoordinatesData
}

pub fn new_jsongenerate() &benchmark.IBenchmark {
	mut bench := &JsonGenerate{
		BaseBenchmark: benchmark.new_base_benchmark('JsonGenerate')
		result_val:    0
		n:             helper.config_i64('JsonGenerate', 'coords')
	}
	return bench
}

pub fn (b JsonGenerate) name() string {
	return 'JsonGenerate'
}

struct CoordinateData {
	x    f64
	y    f64
	z    f64
	name string
	opts map[string][]OptsType
}

struct CoordinatesData {
	coordinates []CoordinateData
	info        string
}

pub fn (mut b JsonGenerate) prepare() {
	mut coordinates := []CoordinateData{cap: int(b.n)}

	for _ in 0 .. b.n {
		x := round_f64(helper.next_float(1.0), 8)
		y := round_f64(helper.next_float(1.0), 8)
		z := round_f64(helper.next_float(1.0), 8)

		name_str := '${helper.next_float(1.0):.7f} ${helper.next_int(10000)}'

		opts := {
			'1': [OptsType(1), OptsType(true)]
		}

		coordinates << CoordinateData{
			x:    x
			y:    y
			z:    z
			name: name_str
			opts: opts
		}
	}

	b.data = CoordinatesData{
		coordinates: coordinates
		info:        'some info'
	}
}

fn round_f64(value f64, decimals int) f64 {
	multiplier := math.pow(10, f64(decimals))
	return math.round(value * multiplier) / multiplier
}

pub fn (mut b JsonGenerate) run(iteration_id int) {
	_ = iteration_id

	b.text = json.encode(b.data)

	if b.text.starts_with('{"coordinates":') {
		b.result_val++
	}
}

pub fn (b JsonGenerate) checksum() u32 {
	return b.result_val
}

fn (b JsonGenerate) get_result() string {
	return b.text
}

pub struct JsonParseDom {
	benchmark.BaseBenchmark
mut:
	result_val u32
	text       string
}

pub fn new_jsonparsedom() &benchmark.IBenchmark {
	mut bench := &JsonParseDom{
		BaseBenchmark: benchmark.new_base_benchmark('JsonParseDom')
		result_val:    0
	}
	return bench
}

pub fn (b JsonParseDom) name() string {
	return 'JsonParseDom'
}

pub fn (mut b JsonParseDom) prepare() {
	mut jg := JsonGenerate{
		BaseBenchmark: benchmark.new_base_benchmark('JsonGenerate')
		n:             b.BaseBenchmark.config_i64('coords')
	}
	jg.n = int(helper.config_i64('JsonParseDom', 'coords'))
	jg.prepare()
	jg.run(0)
	b.text = jg.get_result()
}

pub fn (mut b JsonParseDom) run(iteration_id int) {
	_ = iteration_id

	any_json_value := json2.decode[json2.Any](b.text) or {
		eprintln('Failed to decode: ${err}')
		return
	}

	obj := any_json_value.as_map()
	coordinates_any := obj['coordinates'] or { return }
	coordinates := coordinates_any.arr()

	mut x_sum := f64(0)
	mut y_sum := f64(0)
	mut z_sum := f64(0)

	for coord_any in coordinates {
		coord_obj := coord_any.as_map()

		x_any := coord_obj['x'] or { continue }
		y_any := coord_obj['y'] or { continue }
		z_any := coord_obj['z'] or { continue }

		x := x_any.f64()
		y := y_any.f64()
		z := z_any.f64()

		x_sum += x
		y_sum += y
		z_sum += z
	}

	len := coordinates.len
	if len > 0 {
		x_avg := x_sum / f64(len)
		y_avg := y_sum / f64(len)
		z_avg := z_sum / f64(len)

		b.result_val += helper.checksum_f64(x_avg)
		b.result_val += helper.checksum_f64(y_avg)
		b.result_val += helper.checksum_f64(z_avg)
	}
}

pub fn (b JsonParseDom) checksum() u32 {
	return b.result_val
}

pub struct JsonParseMapping {
	benchmark.BaseBenchmark
mut:
	result_val u32
	text       string
}

pub fn new_jsonparsemapping() &benchmark.IBenchmark {
	mut bench := &JsonParseMapping{
		BaseBenchmark: benchmark.new_base_benchmark('JsonParseMapping')
		result_val:    0
	}
	return bench
}

pub fn (b JsonParseMapping) name() string {
	return 'JsonParseMapping'
}

struct Coordinate {
	x f64
	y f64
	z f64
}

struct Coordinates {
	coordinates []Coordinate
}

pub fn (mut b JsonParseMapping) prepare() {
	mut jg := JsonGenerate{
		BaseBenchmark: benchmark.new_base_benchmark('JsonGenerate')
		n:             b.BaseBenchmark.config_i64('coords')
	}
	jg.n = int(helper.config_i64('JsonParseMapping', 'coords'))
	jg.prepare()
	jg.run(0)
	b.text = jg.get_result()
}

pub fn (mut b JsonParseMapping) run(iteration_id int) {
	_ = iteration_id

	j := json.decode(Coordinates, b.text) or { return }

	mut x_sum := f64(0)
	mut y_sum := f64(0)
	mut z_sum := f64(0)

	for coord in j.coordinates {
		x_sum += coord.x
		y_sum += coord.y
		z_sum += coord.z
	}

	len := j.coordinates.len
	if len > 0 {
		x_avg := x_sum / f64(len)
		y_avg := y_sum / f64(len)
		z_avg := z_sum / f64(len)

		b.result_val += helper.checksum_f64(x_avg)
		b.result_val += helper.checksum_f64(y_avg)
		b.result_val += helper.checksum_f64(z_avg)
	}
}

pub fn (b JsonParseMapping) checksum() u32 {
	return b.result_val
}
