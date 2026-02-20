module fasta

import benchmark
import helper
import strings

const line_length = 60

struct Gene {
	c    u8
	prob f64
}

pub struct Fasta {
	benchmark.BaseBenchmark
pub mut:
	n i64
mut:
	result_buf strings.Builder
}

pub fn new_fasta() &Fasta {
	mut bench := &Fasta{
		BaseBenchmark: benchmark.new_base_benchmark('Fasta')
		n:             helper.config_i64('Fasta', 'n')
		result_buf:    strings.new_builder(0)
	}
	return bench
}

pub fn (b Fasta) name() string {
	return 'Fasta'
}

fn select_random(genelist []Gene) u8 {
	r := helper.next_float(1.0)
	if r < genelist[0].prob {
		return genelist[0].c
	}

	mut lo := 0
	mut hi := genelist.len - 1

	for hi > lo + 1 {
		i := (hi + lo) / 2
		if r < genelist[i].prob {
			hi = i
		} else {
			lo = i
		}
	}

	return genelist[hi].c
}

fn (mut f Fasta) make_random_fasta(id string, desc string, genelist []Gene, n_iter int) {
	f.result_buf.write_string('>')
	f.result_buf.write_string(id)
	f.result_buf.write_string(' ')
	f.result_buf.write_string(desc)
	f.result_buf.write_u8(`\n`)

	mut todo := n_iter

	for todo > 0 {
		m := if todo < line_length { todo } else { line_length }

		for _ in 0 .. m {
			f.result_buf.write_u8(select_random(genelist))
		}

		f.result_buf.write_u8(`\n`)
		todo -= line_length
	}
}

fn (mut f Fasta) make_repeat_fasta(id string, desc string, s string, n_iter int) {
	f.result_buf.write_string('>${id} ${desc}\n')
	mut todo := n_iter
	mut k := 0
	kn := s.len

	for todo > 0 {
		mut m := if todo < line_length { todo } else { line_length }

		for m >= kn - k {
			f.result_buf.write_string(s[k..])
			m -= (kn - k)
			k = 0
		}

		f.result_buf.write_string(s[k..k + m])
		f.result_buf.write_u8(`\n`)
		k += m

		todo -= line_length
	}
}

pub fn (mut f Fasta) run(iteration_id int) {
	_ = iteration_id

	iub := [
		Gene{`a`, 0.27},
		Gene{`c`, 0.39},
		Gene{`g`, 0.51},
		Gene{`t`, 0.78},
		Gene{`B`, 0.8},
		Gene{`D`, 0.8200000000000001},
		Gene{`H`, 0.8400000000000001},
		Gene{`K`, 0.8600000000000001},
		Gene{`M`, 0.8800000000000001},
		Gene{`N`, 0.9000000000000001},
		Gene{`R`, 0.9200000000000002},
		Gene{`S`, 0.9400000000000002},
		Gene{`V`, 0.9600000000000002},
		Gene{`W`, 0.9800000000000002},
		Gene{`Y`, 1.0000000000000002},
	]

	homo := [
		Gene{`a`, 0.302954942668},
		Gene{`c`, 0.5009432431601},
		Gene{`g`, 0.6984905497992},
		Gene{`t`, 1.0},
	]

	alu := 'GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA'

	f.make_repeat_fasta('ONE', 'Homo sapiens alu', alu, int(f.n) * 2)
	f.make_random_fasta('TWO', 'IUB ambiguity codes', iub, int(f.n) * 3)
	f.make_random_fasta('THREE', 'Homo sapiens frequency', homo, int(f.n) * 5)
}

pub fn (mut f Fasta) checksum() u32 {
	result_str := f.result_buf.str()
	return helper.checksum_str(result_str)
}

pub fn (mut f Fasta) prepare() {
	f.result_buf = strings.new_builder(0)
}

pub fn (mut f Fasta) get_result() string {
	return f.result_buf.str()
}
