module pidigits

import benchmark
import helper
import strings
import math.big

pub struct PidigitsBenchmark {
	benchmark.BaseBenchmark
	nn i64
mut:
	result strings.Builder
}

pub fn new_pidigits() &benchmark.IBenchmark {
	mut bench := &PidigitsBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark('Pidigits')
		nn:            helper.config_i64('Pidigits', 'amount')
		result:        strings.new_builder(1024)
	}
	return bench
}

pub fn (b PidigitsBenchmark) name() string {
	return 'Pidigits'
}

pub fn (mut b PidigitsBenchmark) run(iteration_id int) {
	_ = iteration_id

	mut i := 0
	mut k := 0
	mut ns := big.zero_int
	mut a := big.zero_int
	mut t := big.zero_int
	mut u := big.zero_int
	mut k1 := 1
	mut n := big.one_int
	mut d := big.one_int

	two := big.integer_from_int(2)
	three := big.integer_from_int(3)
	ten := big.integer_from_int(10)

	for i < int(b.nn) {
		k += 1
		t = n * two
		n = n * big.integer_from_int(k)
		k1 += 2
		mut temp := a + t
		a = temp * big.integer_from_int(k1)
		d = d * big.integer_from_int(k1)
		if a.abs_cmp(n) >= 0 {
			mut temp2 := n * three + a
			mut q := temp2 / d
			u = temp2 % d
			u = u + n
			if d.abs_cmp(u) > 0 {
				ns = ns * ten + q
				i += 1
				if i % 10 == 0 {
					mut ns_str := ns.str()

					if ns_str.len < 10 {
						mut padded := []u8{len: 10 - ns_str.len, init: `0`}
						ns_str = padded.bytestr() + ns_str
					}

					b.result.write_string('${ns_str}\t:${i}\n')
					ns = big.zero_int
				}

				if i >= int(b.nn) {
					break
				}

				mut temp3 := a - (d * q)
				a = temp3 * ten

				n = n * ten
			}
		}
	}

	if ns.abs_cmp(big.zero_int) != 0 {
		mut ns_str := ns.str()
		if ns_str.len < 10 && i % 10 != 0 {
			mut padded := []u8{len: 10 - ns_str.len, init: `0`}
			ns_str = padded.bytestr() + ns_str
		}

		b.result.write_string('${ns_str}\t:${i}\n')
	}
}

pub fn (mut b PidigitsBenchmark) checksum() u32 {
	return helper.checksum_str(b.result.str())
}

pub fn (mut b PidigitsBenchmark) prepare() {
	b.result = strings.new_builder(1024)
}
