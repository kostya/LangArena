module revcomp

import benchmark
import fasta
import helper
import strings

pub struct Revcomp {
	benchmark.BaseBenchmark
mut:
	input        string
	checksum_val u32
	result_buf   strings.Builder
}

pub fn new_revcomp() &benchmark.IBenchmark {
	mut bench := &Revcomp{
		BaseBenchmark: benchmark.new_base_benchmark('Revcomp')
		input:         ''
		checksum_val:  0
		result_buf:    strings.new_builder(0)
	}
	return bench
}

pub fn (b Revcomp) name() string {
	return 'Revcomp'
}

fn init_lookup() []u8 {
	mut table := []u8{len: 256}
	for i in 0 .. 256 {
		table[i] = u8(i)
	}

	from := 'wsatugcyrkmbdhvnATUGCYRKMBDHVN'
	to_ := 'WSTAACGRYMKVHDBNTAACGRYMKVHDBN'

	for i in 0 .. from.len {
		table[from[i]] = to_[i]
	}

	return table
}

const complement_lookup = init_lookup()

fn (mut r Revcomp) revcomp_impl(seq string) {
	bytesize := seq.len
	if bytesize == 0 {
		return
	}

	r.result_buf.go_back_to(0)

	for end_pos := bytesize; end_pos > 0; end_pos -= 60 {
		start_pos := if end_pos - 60 > 0 { end_pos - 60 } else { 0 }

		for i := end_pos - 1; i >= start_pos; i-- {
			b := unsafe { seq.str[i] }
			complement := complement_lookup[b]
			r.result_buf.write_u8(complement)
		}

		r.result_buf.write_u8(`\n`)
	}
}

pub fn (mut r Revcomp) prepare() {
	mut fasta_bench := fasta.new_fasta()
	fasta_bench.n = helper.config_i64('Revcomp', 'n')
	fasta_bench.prepare()
	fasta_bench.run(0)

	fasta_result := fasta_bench.get_result()

	mut seq_builder := strings.new_builder(10000)

	lines := fasta_result.split_into_lines()
	for line in lines {
		if line.len == 0 {
			continue
		}

		if line.starts_with('>') {
			seq_builder.write_string('\n---\n')
		} else {
			seq_builder.write_string(line)
		}
	}

	r.input = seq_builder.str()

	if !r.input.starts_with('\n---\n') {
		r.input = '\n---\n' + r.input
	}

	r.checksum_val = 0
}

pub fn (mut r Revcomp) run(iteration_id int) {
	_ = iteration_id

	r.revcomp_impl(r.input)

	result := r.result_buf.str()

	r.checksum_val += helper.checksum_str(result)
}

pub fn (r Revcomp) checksum() u32 {
	return r.checksum_val
}
