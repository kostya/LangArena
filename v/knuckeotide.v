module knuckeotide

import benchmark
import fasta
import helper

pub struct Knuckeotide {
	benchmark.BaseBenchmark
mut:
	seq        string
	result_str string
}

pub fn new_knuckeotide() &benchmark.IBenchmark {
	mut bench := &Knuckeotide{
		BaseBenchmark: benchmark.new_base_benchmark('Knuckeotide')
		seq:           ''
		result_str:    ''
	}
	return bench
}

pub fn (b Knuckeotide) name() string {
	return 'Knuckeotide'
}

struct FrequencyResult {
	n     int
	table map[string]int
}

fn frequency(seq string, length int) FrequencyResult {
	n := seq.len - length + 1
	mut table := map[string]int{}

	for i in 0 .. n {
		sub := seq[i..i + length]
		table[sub]++
	}

	return FrequencyResult{n, table}
}

fn to_upper(s string) string {
	mut result := []u8{len: s.len}
	for i, c in s {
		if c >= `a` && c <= `z` {
			result[i] = c - 32
		} else {
			result[i] = c
		}
	}
	return result.bytestr()
}

fn to_lower(s string) string {
	mut result := []u8{len: s.len}
	for i, c in s {
		if c >= `A` && c <= `Z` {
			result[i] = c + 32
		} else {
			result[i] = c
		}
	}
	return result.bytestr()
}

@[heap]
struct SortPair {
	key   string
	value int
}

fn (mut k Knuckeotide) sort_by_freq(seq string, length int) {
	res := frequency(seq, length)
	mut pairs := []SortPair{cap: res.table.len}

	for key, value in res.table {
		pairs << SortPair{key, value}
	}

	pairs.sort_with_compare(fn (a &SortPair, b &SortPair) int {
		if a.value != b.value {
			return if b.value > a.value { 1 } else { -1 } 
		}
		return if a.key > b.key {
			1
		} else {
			if a.key < b.key { -1 } else { 0 }
		}
	})

	for pair in pairs {
		percent := f64(pair.value) * 100.0 / f64(res.n)
		key_upper := to_upper(pair.key)
		k.result_str += '${key_upper} ${percent:.3f}\n'
	}
	k.result_str += '\n'
}

fn (mut k Knuckeotide) find_seq(seq string, s string) {
	s_lower := to_lower(s)
	res := frequency(seq, s_lower.len)
	count := res.table[s_lower] or { 0 }

	s_upper := to_upper(s)
	k.result_str += '${count}\t${s_upper}\n'
}

pub fn (mut k Knuckeotide) prepare() {

	mut fasta_bench_raw := fasta.new_fasta()

	mut fasta_bench := fasta_bench_raw as &fasta.Fasta

	n_val := helper.config_i64('Knuckeotide', 'n')
	fasta_bench.n = n_val

	fasta_bench.prepare()
	fasta_bench.run(0)

	res := fasta_bench.get_result()

	lines := res.split_into_lines()
	mut three := false
	k.seq = ''

	for line in lines {
		if line.starts_with('>THREE') {
			three = true
			continue
		}
		if three && line.len > 0 && line[0] != `>` {
			k.seq += line
		}
	}

	k.result_str = ''
}

pub fn (mut k Knuckeotide) run(iteration_id int) {
	_ = iteration_id

	for i in 1 .. 3 {
		k.sort_by_freq(k.seq, i)
	}

	searches := ['ggt', 'ggta', 'ggtatt', 'ggtattttaatt', 'ggtattttaatttatagt']
	for s in searches {
		k.find_seq(k.seq, s)
	}
}

pub fn (k Knuckeotide) checksum() u32 {
	return helper.checksum_str(k.result_str)
}