module distance

import benchmark
import helper
import math

struct StringPair {
	s1 string
	s2 string
}

fn generate_pair_strings(n int, m int) []StringPair {
	mut pairs := []StringPair{len: n}
	chars := 'abcdefghij'.split('')

	for i in 0 .. n {
		len1 := helper.next_int(m) + 4
		len2 := helper.next_int(m) + 4

		mut str1 := ''
		mut str2 := ''

		for _ in 0 .. len1 {
			str1 += chars[helper.next_int(10)]
		}
		for _ in 0 .. len2 {
			str2 += chars[helper.next_int(10)]
		}

		pairs[i] = StringPair{str1, str2}
	}

	return pairs
}

pub struct Jaro {
	benchmark.BaseBenchmark
mut:
	count      int
	size       int
	pairs      []StringPair
	result_val u32
}

pub fn new_jaro() &benchmark.IBenchmark {
	mut bench := &Jaro{
		BaseBenchmark: benchmark.new_base_benchmark('Distance::Jaro')
		result_val:    0
	}
	return bench
}

pub fn (b Jaro) name() string {
	return 'Distance::Jaro'
}

pub fn (mut b Jaro) prepare() {
	b.count = int(helper.config_i64('Distance::Jaro', 'count'))
	b.size = int(helper.config_i64('Distance::Jaro', 'size'))
	b.pairs = generate_pair_strings(b.count, b.size)
	b.result_val = 0
}

fn jaro_calc(s1 string, s2 string) f64 {
	s1_bytes := s1.bytes()
	s2_bytes := s2.bytes()

	len1 := s1_bytes.len
	len2 := s2_bytes.len

	if len1 == 0 || len2 == 0 {
		return 0.0
	}

	mut match_dist := math.max(len1, len2) / 2 - 1
	if match_dist < 0 {
		match_dist = 0
	}

	mut s1_matches := []bool{len: len1, init: false}
	mut s2_matches := []bool{len: len2, init: false}

	mut matches := 0
	for i in 0 .. len1 {
		start := math.max(0, i - match_dist)
		end := math.min(len2 - 1, i + match_dist)

		for j in start .. end + 1 {
			if !s2_matches[j] && s1_bytes[i] == s2_bytes[j] {
				s1_matches[i] = true
				s2_matches[j] = true
				matches++
				break
			}
		}
	}

	if matches == 0 {
		return 0.0
	}

	mut transpositions := 0
	mut k := 0
	for i in 0 .. len1 {
		if s1_matches[i] {
			for k < len2 && !s2_matches[k] {
				k++
			}
			if k < len2 {
				if s1_bytes[i] != s2_bytes[k] {
					transpositions++
				}
				k++
			}
		}
	}
	transpositions /= 2

	m := f64(matches)
	return (m / f64(len1) + m / f64(len2) + (m - f64(transpositions)) / m) / 3.0
}

pub fn (mut b Jaro) run(iteration_id int) {
	for pair in b.pairs {
		b.result_val += u32(jaro_calc(pair.s1, pair.s2) * 1000)
	}
}

pub fn (b Jaro) checksum() u32 {
	return b.result_val
}

pub struct NGram {
	benchmark.BaseBenchmark
mut:
	count      int
	size       int
	pairs      []StringPair
	result_val u32
	n          int
}

pub fn new_ngram() &benchmark.IBenchmark {
	mut bench := &NGram{
		BaseBenchmark: benchmark.new_base_benchmark('Distance::NGram')
		result_val:    0
		n:             4
	}
	return bench
}

pub fn (b NGram) name() string {
	return 'Distance::NGram'
}

pub fn (mut b NGram) prepare() {
	b.count = int(helper.config_i64('Distance::NGram', 'count'))
	b.size = int(helper.config_i64('Distance::NGram', 'size'))
	b.pairs = generate_pair_strings(b.count, b.size)
	b.result_val = 0
}

fn ngram_calc(b NGram, s1 string, s2 string) f64 {
	s1_bytes := s1.bytes()
	s2_bytes := s2.bytes()

	len1 := s1_bytes.len
	len2 := s2_bytes.len

	if len1 < b.n || len2 < b.n {
		return 0.0
	}

	mut grams1 := map[u32]int{}
	mut grams2 := map[u32]int{}
	mut intersection := 0

	for i in 0 .. (len1 - b.n + 1) {
		gram := (u32(s1_bytes[i]) << 24) | (u32(s1_bytes[i + 1]) << 16) | (u32(s1_bytes[i + 2]) << 8) | u32(s1_bytes[
			i + 3])

		grams1[gram] = grams1[gram] or { 0 } + 1
	}

	for i in 0 .. (len2 - b.n + 1) {
		gram := (u32(s2_bytes[i]) << 24) | (u32(s2_bytes[i + 1]) << 16) | (u32(s2_bytes[i + 2]) << 8) | u32(s2_bytes[
			i + 3])

		grams2[gram] = grams2[gram] or { 0 } + 1

		if count1 := grams1[gram] {
			if grams2[gram] <= count1 {
				intersection++
			}
		}
	}

	total := grams1.len + grams2.len
	return if total > 0 { f64(intersection) / f64(total) } else { 0.0 }
}

pub fn (mut b NGram) run(iteration_id int) {
	for pair in b.pairs {
		b.result_val += u32(ngram_calc(b, pair.s1, pair.s2) * 1000)
	}
}

pub fn (b NGram) checksum() u32 {
	return b.result_val
}
