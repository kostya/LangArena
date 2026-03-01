module sieve

import benchmark
import helper
import math

pub struct Sieve {
	benchmark.BaseBenchmark
	limit i64
mut:
	checksum_val u32
}

pub fn new_sieve() &benchmark.IBenchmark {
	mut bench := &Sieve{
		BaseBenchmark: benchmark.new_base_benchmark('Etc::Sieve')
		limit:         helper.config_i64('Etc::Sieve', 'limit')
		checksum_val:  0
	}
	return bench
}

pub fn (b Sieve) name() string {
	return 'Etc::Sieve'
}

fn run_sieve(limit int) int {
	mut primes := []u8{len: limit + 1, init: 1}
	primes[0] = 0
	primes[1] = 0

	sqrt_limit := int(math.sqrt(f64(limit)))

	for p in 2 .. sqrt_limit + 1 {
		if primes[p] == 1 {
			mut multiple := p * p
			for multiple <= limit {
				primes[multiple] = 0
				multiple += p
			}
		}
	}

	mut last_prime := 2
	mut count := 1

	mut n := 3
	for n <= limit {
		if primes[n] == 1 {
			last_prime = n
			count++
		}
		n += 2
	}

	return last_prime + count
}

pub fn (mut s Sieve) run(iteration_id int) {
	result := run_sieve(int(s.limit))
	s.checksum_val += u32(result)
}

pub fn (s Sieve) checksum() u32 {
	return s.checksum_val
}

pub fn (mut s Sieve) prepare() {
	s.checksum_val = 0
}
