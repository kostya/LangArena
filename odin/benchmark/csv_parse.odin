package benchmark

import "core:encoding/csv"
import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"

CsvParse :: struct {
	using base: Benchmark,
	rows:       int,
	data:       string,
	result_val: u32,
}

csvparse_name :: proc(bench: ^Benchmark) -> string {
	return "CSV::Parse"
}

csvparse_prepare :: proc(bench: ^Benchmark) {
	cp := cast(^CsvParse)bench

	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	for i in 0 ..< cp.rows {
		c := 'A' + rune(i % 26)
		x := next_float()
		z := next_float()
		y := next_float()
		strings.write_byte(&b, '"')
		strings.write_string(&b, "point ")
		strings.write_rune(&b, c)
		strings.write_string(&b, "\\n, \"\"")
		strings.write_int(&b, i % 100)
		strings.write_string(&b, "\"\"\"")
		strings.write_byte(&b, ',')
		fmt.sbprintf(&b, "%.10f,", x)
		strings.write_byte(&b, ',')
		fmt.sbprintf(&b, "%.10f,", z)
		strings.write_byte(&b, '"')
		strings.write_byte(&b, '[')
		if i % 2 == 0 {
			strings.write_string(&b, "true")
		} else {
			strings.write_string(&b, "false")
		}
		strings.write_string(&b, "\\n, ")
		strings.write_int(&b, i % 100)
		strings.write_byte(&b, ']')
		strings.write_byte(&b, '"')
		strings.write_byte(&b, ',')

		fmt.sbprintf(&b, "%.10f\n", y)
	}

	cp.data = strings.to_string(b)
}

Point :: struct {
	x, y, z: f64,
}

csvparse_run :: proc(bench: ^Benchmark, iteration_id: int) {
	cp := cast(^CsvParse)bench

	points := parse_points(cp.data)
	defer delete(points)

	if len(points) == 0 {
		return
	}

	x_sum, y_sum, z_sum: f64 = 0, 0, 0

	for p in points {
		x_sum += p.x
		y_sum += p.y
		z_sum += p.z
	}

	count := f64(len(points))
	x_avg := x_sum / count
	y_avg := y_sum / count
	z_avg := z_sum / count

	cp.result_val += checksum_f64(x_avg) + checksum_f64(y_avg) + checksum_f64(z_avg)
}

parse_points :: proc(data: string) -> []Point {
	points := make([dynamic]Point)

	r: csv.Reader
	csv.reader_init_with_string(&r, data)
	defer csv.reader_destroy(&r)

	for {
		record, idx, err, more := csv.iterator_next(&r)
		if err != nil || !more {
			break
		}

		x, _ := strconv.parse_f64(record[1])
		z, _ := strconv.parse_f64(record[3])
		y, _ := strconv.parse_f64(record[5])
		append(&points, Point{x, y, z})
	}

	return points[:]
}

csvparse_checksum :: proc(bench: ^Benchmark) -> u32 {
	cp := cast(^CsvParse)bench
	return cp.result_val
}

create_csvparse :: proc() -> ^Benchmark {
	cp := new(CsvParse)
	cp.name = "CSV::Parse"
	cp.vtable = default_vtable()

	cp.vtable.prepare = csvparse_prepare
	cp.vtable.run = csvparse_run
	cp.vtable.checksum = csvparse_checksum

	cp.rows = int(config_i64("CSV::Parse", "rows"))

	return cast(^Benchmark)cp
}
