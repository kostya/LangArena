module regexdna

import benchmark
import fasta
import helper
import strings
import srackham.pcre2 as pcre

pub struct RegexDna {
	benchmark.BaseBenchmark
mut:
	seq        string
	result_buf strings.Builder
	ilen       int
	clen       int
}

pub fn new_regexdna() &benchmark.IBenchmark {
	mut bench := &RegexDna{
		BaseBenchmark: benchmark.new_base_benchmark('RegexDna')
		seq:           ''
		result_buf:    strings.new_builder(0)
		ilen:          0
		clen:          0
	}
	return bench
}

pub fn (b RegexDna) name() string {
	return 'RegexDna'
}

const patterns = [
	'agggtaaa|tttaccct',
	'[cgt]gggtaaa|tttaccc[acg]',
	'a[act]ggtaaa|tttacc[agt]t',
	'ag[act]gtaaa|tttac[agt]ct',
	'agg[act]taaa|ttta[agt]cct',
	'aggg[acg]aaa|ttt[cgt]ccct',
	'agggt[cgt]aa|tt[acg]accct',
	'agggta[cgt]a|t[acg]taccct',
	'agggtaa[cgt]|[acg]ttaccct',
]

struct Replacement {
	from string
	to   string
}

const replacements = [
	Replacement{'B', '(c|g|t)'},
	Replacement{'D', '(a|g|t)'},
	Replacement{'H', '(a|c|t)'},
	Replacement{'K', '(g|t)'},
	Replacement{'M', '(a|c)'},
	Replacement{'N', '(a|c|g|t)'},
	Replacement{'R', '(a|g)'},
	Replacement{'S', '(c|g)'},
	Replacement{'V', '(a|c|g)'},
	Replacement{'W', '(a|t)'},
	Replacement{'Y', '(c|t)'},
]

fn count_pattern_fast(seq string, pattern string) int {
	re := pcre.compile(pattern) or { return 0 }

	matches := re.find_all(seq)
	return matches.len
}

pub fn (mut r RegexDna) prepare() {
	mut fasta_bench := fasta.new_fasta()
	mut f := fasta_bench as &fasta.Fasta
	f.n = helper.config_i64('RegexDna', 'n')

	f.prepare()
	f.run(0)
	fasta_result := f.get_result()

	lines := fasta_result.split_into_lines()
	mut seq_builder := strings.new_builder(fasta_result.len)
	r.ilen = 0

	for line in lines {
		if line.len == 0 {
			continue
		}

		r.ilen += line.len + 1

		if line[0] != `>` {
			seq_builder.write_string(line)
		}
	}

	r.seq = seq_builder.str()
	r.clen = r.seq.len

	r.result_buf = strings.new_builder(0)
}

pub fn (mut r RegexDna) run(iteration_id int) {
	for pattern in patterns {
		count := count_pattern_fast(r.seq, pattern)
		r.result_buf.write_string('${pattern} ${count}\n')
	}

	mut seq2 := strings.new_builder(r.seq.len * 2)

	mut replace_map := [256]string{}
	for repl in replacements {
		replace_map[repl.from[0]] = repl.to
	}

	for i in 0 .. r.seq.len {
		ch := r.seq[i]
		replacement := replace_map[ch]
		if replacement.len > 0 {
			seq2.write_string(replacement)
		} else {
			seq2.write_u8(ch)
		}
	}

	seq2_str := seq2.str()

	r.result_buf.write_string('\n${r.ilen}\n${r.clen}\n${seq2_str.len}\n')
}

pub fn (mut r RegexDna) checksum() u32 {
	return helper.checksum_str(r.result_buf.str())
}
