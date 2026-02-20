module fannkuchredux

import benchmark
import helper

pub struct Fannkuchredux {
	benchmark.BaseBenchmark
	n i64
mut:
	result_val u32
}

pub fn new_fannkuchredux() &benchmark.IBenchmark {
	mut bench := &Fannkuchredux{
		BaseBenchmark: benchmark.new_base_benchmark('Fannkuchredux')
		n:             helper.config_i64('Fannkuchredux', 'n')
		result_val:    0
	}
	return bench
}

pub fn (b Fannkuchredux) name() string {
	return 'Fannkuchredux'
}

fn fannkuchredux_impl(n int) (int, int) {
	mut perm1 := [32]int{}
	mut perm := [32]int{}
	mut count := [32]int{}

	for i in 0 .. n {
		perm1[i] = i
	}
	mut max_flips_count := 0
	mut perm_count := 0
	mut checksum := 0
	mut r := n

	for {
		for r > 1 {
			count[r - 1] = r
			r--
		}

		for i in 0 .. n {
			perm[i] = perm1[i]
		}

		mut flips_count := 0
		mut k := perm[0]

		for k != 0 {
			k2 := (k + 1) >> 1
			for i in 0 .. k2 {
				j := k - i

				tmp := perm[i]
				perm[i] = perm[j]
				perm[j] = tmp
			}
			flips_count++
			k = perm[0]
		}

		if flips_count > max_flips_count {
			max_flips_count = flips_count
		}

		if perm_count % 2 == 0 {
			checksum += flips_count
		} else {
			checksum -= flips_count
		}

		for {
			if r == n {
				return checksum, max_flips_count
			}

			perm0 := perm1[0]
			for i in 0 .. r {
				perm1[i] = perm1[i + 1]
			}
			perm1[r] = perm0

			count[r]--
			if count[r] > 0 {
				break
			}
			r++
		}
		perm_count++
	}

	return checksum, max_flips_count
}

pub fn (mut b Fannkuchredux) run(iteration_id int) {
	checksum, max_flips := fannkuchredux_impl(int(b.n))
	b.result_val += u32(checksum) * 100 + u32(max_flips)
}

pub fn (b Fannkuchredux) checksum() u32 {
	return b.result_val
}

pub fn (mut b Fannkuchredux) prepare() {
	b.result_val = 0
}
