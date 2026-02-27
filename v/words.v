module words

import benchmark
import helper

pub struct Words {
	benchmark.BaseBenchmark
	words    i64
	word_len i64
mut:
	text         string
	checksum_val u32
}

pub fn new_words() &benchmark.IBenchmark {
	mut bench := &Words{
		BaseBenchmark: benchmark.new_base_benchmark('Etc::Words')
		words:         helper.config_i64('Etc::Words', 'words')
		word_len:      helper.config_i64('Etc::Words', 'word_len')
		text:          ''
		checksum_val:  0
	}
	return bench
}

pub fn (b Words) name() string {
	return 'Etc::Words'
}

pub fn (mut w Words) prepare() {
	chars := 'abcdefghijklmnopqrstuvwxyz'
	mut words_list := []string{cap: int(w.words)}

	for _ in 0 .. int(w.words) {
		len := helper.next_int(int(w.word_len)) + helper.next_int(3) + 3
		mut word := ''
		for _ in 0 .. len {
			idx := helper.next_int(chars.len)
			word += chars[idx].ascii_str()
		}
		words_list << word
	}

	w.text = words_list.join(' ')
}

pub fn (mut w Words) run(iteration_id int) {
	mut frequencies := map[string]int{}

	words_array := w.text.split(' ')
	for word in words_array {
		if word == '' {
			continue
		}
		frequencies[word]++
	}

	mut max_word := ''
	mut max_count := 0
	for word, count in frequencies {
		if count > max_count {
			max_count = count
			max_word = word
		}
	}

	freq_size := u32(frequencies.len)
	word_checksum := u32(helper.checksum_str(max_word))

	w.checksum_val += u32(max_count) + word_checksum + freq_size
}

pub fn (w &Words) checksum() u32 {
	return w.checksum_val
}
