module compress

import benchmark
import helper

fn generate_test_data(data_size i64) []u8 {
	if data_size <= 0 {
		return []u8{}
	}

	pattern := 'ABRACADABRA'
	mut data := []u8{len: int(data_size)}
	for i in 0 .. data_size {
		data[i] = pattern[int(i) % pattern.len]
	}
	return data
}

struct BWTResult {
pub:
	transformed  []u8
	original_idx int
}

pub struct BWTEncode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	bwt_result BWTResult
}

pub fn new_bwtencode() &benchmark.IBenchmark {
	mut bench := &BWTEncode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::BWTEncode')
		result_val:    0
		size_val:      helper.config_i64('Compress::BWTEncode', 'size')
	}
	return bench
}

fn bwt_transform(input []u8) BWTResult {
	n := input.len
	if n == 0 {
		return BWTResult{[]u8{}, 0}
	}

	mut sa := []int{len: n}
	for i in 0 .. n {
		sa[i] = i
	}

	mut buckets := [][]int{len: 256}
	for idx in sa {
		first_char := input[idx]
		buckets[first_char] << idx
	}

	mut pos := 0
	for bucket in buckets {
		for idx in bucket {
			sa[pos] = idx
			pos++
		}
	}

	if n > 1 {
		struct Pair {
			first  int
			second int
		}

		mut rank := []int{len: n}
		mut current_rank := 0
		mut prev_char := input[sa[0]]

		for i in 0 .. n {
			idx := sa[i]
			curr_char := input[idx]
			if curr_char != prev_char {
				current_rank++
				prev_char = curr_char
			}
			rank[idx] = current_rank
		}

		mut k := 1
		for k < n {
			mut pairs := []Pair{len: n}

			for i in 0 .. n {
				pairs[i] = Pair{rank[i], rank[(i + k) % n]}
			}

			sa.sort_with_compare(fn [pairs] (a &int, b &int) int {
				idx_a := *a
				idx_b := *b
				pair_a := pairs[idx_a]
				pair_b := pairs[idx_b]

				if pair_a.first != pair_b.first {
					return pair_a.first - pair_b.first
				}
				return pair_a.second - pair_b.second
			})

			mut new_rank := []int{len: n}
			new_rank[sa[0]] = 0

			for i in 1 .. n {
				prev_idx := sa[i - 1]
				curr_idx := sa[i]
				prev_pair := pairs[prev_idx]
				curr_pair := pairs[curr_idx]

				are_equal := prev_pair.first == curr_pair.first
					&& prev_pair.second == curr_pair.second

				new_rank[curr_idx] = new_rank[prev_idx] + if are_equal { 0 } else { 1 }
			}

			rank = new_rank.clone()
			k *= 2
		}
	}

	mut transformed := []u8{len: n}
	mut original_idx := 0

	for i in 0 .. n {
		suffix := sa[i]
		if suffix == 0 {
			transformed[i] = input[n - 1]
			original_idx = i
		} else {
			transformed[i] = input[suffix - 1]
		}
	}

	return BWTResult{transformed, original_idx}
}

pub fn (b BWTEncode) name() string {
	return 'Compress::BWTEncode'
}

pub fn (mut b BWTEncode) prepare() {
	b.test_data = generate_test_data(b.size_val)
	b.result_val = 0
}

pub fn (mut b BWTEncode) run(iteration_id int) {
	b.bwt_result = bwt_transform(b.test_data)
	b.result_val += u32(b.bwt_result.transformed.len)
}

pub fn (b BWTEncode) checksum() u32 {
	return b.result_val
}

pub struct BWTDecode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	inverted   []u8
	bwt_result BWTResult
}

pub fn new_bwtdecode() &benchmark.IBenchmark {
	mut bench := &BWTDecode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::BWTDecode')
		result_val:    0
		size_val:      helper.config_i64('Compress::BWTDecode', 'size')
	}
	return bench
}

fn bwt_inverse(bwt_result BWTResult) []u8 {
	bwt := bwt_result.transformed
	n := bwt.len
	if n == 0 {
		return []u8{}
	}

	mut counts := []int{len: 256}
	for b in bwt {
		counts[b]++
	}

	mut positions := []int{len: 256}
	mut total := 0
	for i in 0 .. 256 {
		positions[i] = total
		total += counts[i]
	}

	mut next := []int{len: n}
	mut temp_counts := []int{len: 256}

	for i in 0 .. n {
		b := bwt[i]
		pos := positions[b] + temp_counts[b]
		next[pos] = i
		temp_counts[b]++
	}

	mut result := []u8{len: n}
	mut idx := bwt_result.original_idx

	for i in 0 .. n {
		idx = next[idx]
		result[i] = bwt[idx]
	}

	return result
}

pub fn (b BWTDecode) name() string {
	return 'Compress::BWTDecode'
}

pub fn (mut b BWTDecode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)

	mut encoder := new_bwtencode() as BWTEncode
	encoder.size_val = b.size_val
	encoder.prepare()
	encoder.run(0)

	b.bwt_result = encoder.bwt_result
	b.result_val = 0
}

pub fn (mut b BWTDecode) run(iteration_id int) {
	b.inverted = bwt_inverse(b.bwt_result)
	b.result_val += u32(b.inverted.len)
}

pub fn (b BWTDecode) checksum() u32 {
	mut res := b.result_val
	if b.test_data.len == b.inverted.len {
		mut equal := true
		for i in 0 .. b.test_data.len {
			if b.test_data[i] != b.inverted[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}

struct HuffmanNode {
pub:
	frequency int
	byte_val  u8
	is_leaf   bool
mut:
	left  &HuffmanNode = unsafe { nil }
	right &HuffmanNode = unsafe { nil }
}

struct HuffmanCodes {
pub mut:
	code_lengths []int
	codes        []int
}

struct EncodedResult {
pub mut:
	data        []u8
	bit_count   int
	frequencies []int
}

pub struct HuffEncode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	encoded    EncodedResult
}

pub fn new_huffencode() &benchmark.IBenchmark {
	mut bench := &HuffEncode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::HuffEncode')
		result_val:    0
		size_val:      helper.config_i64('Compress::HuffEncode', 'size')
	}
	return bench
}

fn build_huffman_tree(frequencies []int) &HuffmanNode {
	mut heap := []&HuffmanNode{}

	for i in 0 .. 256 {
		if frequencies[i] > 0 {
			heap << &HuffmanNode{
				frequency: frequencies[i]
				byte_val:  u8(i)
				is_leaf:   true
			}
		}
	}

	for i in 0 .. heap.len - 1 {
		for j in i + 1 .. heap.len {
			if heap[i].frequency > heap[j].frequency {
				heap[i], heap[j] = heap[j], heap[i]
			}
		}
	}

	if heap.len == 1 {
		node := heap[0]
		return &HuffmanNode{
			frequency: node.frequency
			is_leaf:   false
			left:      node
			right:     &HuffmanNode{
				frequency: 0
				is_leaf:   true
			}
		}
	}

	for heap.len > 1 {
		left := heap[0]
		right := heap[1]
		heap.delete(0)
		heap.delete(0)

		parent := &HuffmanNode{
			frequency: left.frequency + right.frequency
			is_leaf:   false
			left:      left
			right:     right
		}

		mut inserted := false
		for i in 0 .. heap.len {
			if parent.frequency < heap[i].frequency {
				heap.insert(i, parent)
				inserted = true
				break
			}
		}
		if !inserted {
			heap << parent
		}
	}

	return heap[0]
}

fn build_huffman_codes(node &HuffmanNode, code u32, length int, mut huffman_codes HuffmanCodes) {
	if node.is_leaf {
		if length > 0 || node.byte_val != 0 {
			idx := node.byte_val
			huffman_codes.code_lengths[idx] = length
			huffman_codes.codes[idx] = int(code)
		}
	} else {
		if node.left != unsafe { nil } {
			build_huffman_codes(node.left, code << 1, length + 1, mut huffman_codes)
		}
		if node.right != unsafe { nil } {
			build_huffman_codes(node.right, (code << 1) | 1, length + 1, mut huffman_codes)
		}
	}
}

fn huffman_encode(data []u8, huffman_codes HuffmanCodes, frequencies []int) EncodedResult {
	mut result := []u8{cap: data.len * 2}
	mut current_byte := u8(0)
	mut bit_pos := 0
	mut total_bits := 0

	for b in data {
		idx := b
		code := huffman_codes.codes[idx]
		length := huffman_codes.code_lengths[idx]

		for i := length - 1; i >= 0; i-- {
			if (code & (1 << i)) != 0 {
				current_byte |= 1 << (7 - bit_pos)
			}
			bit_pos++
			total_bits++

			if bit_pos == 8 {
				result << current_byte
				current_byte = 0
				bit_pos = 0
			}
		}
	}

	if bit_pos > 0 {
		result << current_byte
	}

	return EncodedResult{result, total_bits, frequencies}
}

pub fn (b HuffEncode) name() string {
	return 'Compress::HuffEncode'
}

pub fn (mut b HuffEncode) prepare() {
	b.test_data = generate_test_data(b.size_val)
	b.result_val = 0
}

pub fn (mut b HuffEncode) run(iteration_id int) {
	mut frequencies := []int{len: 256, init: 0}
	for byte in b.test_data {
		frequencies[int(byte)]++
	}

	tree := build_huffman_tree(frequencies)

	mut huffman_codes := HuffmanCodes{
		code_lengths: []int{len: 256, init: 0}
		codes:        []int{len: 256, init: 0}
	}
	build_huffman_codes(tree, u32(0), 0, mut huffman_codes)

	b.encoded = huffman_encode(b.test_data, huffman_codes, frequencies)
	b.result_val += u32(b.encoded.data.len)
}

pub fn (b HuffEncode) checksum() u32 {
	return b.result_val
}

pub struct HuffDecode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	decoded    []u8
	encoded    EncodedResult
}

pub fn new_huffdecode() &benchmark.IBenchmark {
	mut bench := &HuffDecode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::HuffDecode')
		result_val:    0
		size_val:      helper.config_i64('Compress::HuffDecode', 'size')
	}
	return bench
}

fn huffman_decode(encoded []u8, root &HuffmanNode, bit_count int) []u8 {
	mut result := []u8{len: bit_count, cap: bit_count}
	mut result_len := 0

	mut current_node := unsafe { root }
	mut bits_processed := 0
	mut byte_index := 0

	for bits_processed < bit_count && byte_index < encoded.len {
		byte_val := encoded[byte_index]
		byte_index++

		mut bit_pos := 7
		for bit_pos >= 0 && bits_processed < bit_count {
			bit := ((byte_val >> bit_pos) & 1) == 1
			current_node = if bit {
				unsafe { current_node.right }
			} else {
				unsafe { current_node.left }
			}
			bits_processed++

			if current_node.is_leaf {
				result[result_len] = current_node.byte_val
				result_len++
				current_node = unsafe { root }
			}
			bit_pos--
		}
	}

	return result[..result_len]
}

pub fn (b HuffDecode) name() string {
	return 'Compress::HuffDecode'
}

pub fn (mut b HuffDecode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)

	mut encoder := new_huffencode() as HuffEncode
	encoder.size_val = b.size_val
	encoder.prepare()
	encoder.run(0)

	b.encoded = encoder.encoded
	b.result_val = 0
}

pub fn (mut b HuffDecode) run(iteration_id int) {
	tree := build_huffman_tree(b.encoded.frequencies)
	b.decoded = huffman_decode(b.encoded.data, tree, b.encoded.bit_count)
	b.result_val += u32(b.decoded.len)
}

pub fn (b HuffDecode) checksum() u32 {
	mut res := b.result_val
	if b.test_data.len == b.decoded.len {
		mut equal := true
		for i in 0 .. b.test_data.len {
			if b.test_data[i] != b.decoded[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}

struct ArithFreqTable {
mut:
	total int
	low   [256]int
	high  [256]int
}

fn new_arith_freq_table(frequencies []int) ArithFreqTable {
	mut ft := ArithFreqTable{
		total: 0
	}
	for f in frequencies {
		ft.total += f
	}

	mut cum := 0
	for i := 0; i < 256; i++ {
		ft.low[i] = cum
		cum += frequencies[i]
		ft.high[i] = cum
	}
	return ft
}

struct BitOutputStream {
mut:
	buffer       int
	bit_pos      int
	bytes        []u8
	bits_written int
}

fn (mut out BitOutputStream) write_bit(bit int) {
	out.buffer = (out.buffer << 1) | (bit & 1)
	out.bit_pos++
	out.bits_written++

	if out.bit_pos == 8 {
		out.bytes << u8(out.buffer)
		out.buffer = 0
		out.bit_pos = 0
	}
}

fn (mut out BitOutputStream) flush() []u8 {
	if out.bit_pos > 0 {
		out.buffer <<= (8 - out.bit_pos)
		out.bytes << u8(out.buffer)
	}
	return out.bytes.clone()
}

struct ArithEncodedResult {
pub:
	data        []u8
	bit_count   int
	frequencies []int
}

pub struct ArithEncode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	encoded    ArithEncodedResult
}

pub fn new_arithencode() &benchmark.IBenchmark {
	mut bench := &ArithEncode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::ArithEncode')
		result_val:    0
		size_val:      helper.config_i64('Compress::ArithEncode', 'size')
	}
	return bench
}

fn arith_encode(data []u8) ArithEncodedResult {
	mut frequencies := []int{len: 256, init: 0}
	for byte in data {
		idx := int(byte)
		frequencies[idx] = frequencies[idx] + 1
	}

	freq_table := new_arith_freq_table(frequencies)

	mut low := u64(0)
	mut high := u64(0xFFFFFFFF)
	mut pending := 0
	mut output := BitOutputStream{}

	for byte in data {
		idx := int(byte)
		range_val := high - low + 1

		high = low + (range_val * u64(freq_table.high[idx]) / u64(freq_table.total)) - 1
		low = low + (range_val * u64(freq_table.low[idx]) / u64(freq_table.total))

		for {
			if high < 0x80000000 {
				output.write_bit(0)
				for _ in 0 .. pending {
					output.write_bit(1)
				}
				pending = 0
			} else if low >= 0x80000000 {
				output.write_bit(1)
				for _ in 0 .. pending {
					output.write_bit(0)
				}
				pending = 0
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				pending++
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			high &= 0xFFFFFFFF
		}
	}

	pending++
	if low < 0x40000000 {
		output.write_bit(0)
		for _ in 0 .. pending {
			output.write_bit(1)
		}
	} else {
		output.write_bit(1)
		for _ in 0 .. pending {
			output.write_bit(0)
		}
	}

	return ArithEncodedResult{
		data:        output.flush()
		bit_count:   output.bits_written
		frequencies: frequencies
	}
}

pub fn (b ArithEncode) name() string {
	return 'Compress::ArithEncode'
}

pub fn (mut b ArithEncode) prepare() {
	b.test_data = generate_test_data(b.size_val)
	b.result_val = 0
}

pub fn (mut b ArithEncode) run(iteration_id int) {
	b.encoded = arith_encode(b.test_data)
	b.result_val += u32(b.encoded.data.len)
}

pub fn (b ArithEncode) checksum() u32 {
	return b.result_val
}

struct BitInputStream {
	bytes []u8
mut:
	byte_pos     int
	bit_pos      int
	current_byte int
}

fn new_bit_input_stream(bytes []u8) BitInputStream {
	current := if bytes.len > 0 { int(bytes[0]) } else { 0 }
	return BitInputStream{
		bytes:        bytes
		byte_pos:     0
		bit_pos:      0
		current_byte: current
	}
}

fn (mut b BitInputStream) read_bit() int {
	if b.bit_pos == 8 {
		b.byte_pos++
		b.bit_pos = 0
		b.current_byte = if b.byte_pos < b.bytes.len { int(b.bytes[b.byte_pos]) } else { 0 }
	}

	bit := (b.current_byte >> (7 - b.bit_pos)) & 1
	b.bit_pos++
	return bit
}

pub struct ArithDecode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	decoded    []u8
	encoded    ArithEncodedResult
}

pub fn new_arithdecode() &benchmark.IBenchmark {
	mut bench := &ArithDecode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::ArithDecode')
		result_val:    0
		size_val:      helper.config_i64('Compress::ArithDecode', 'size')
	}
	return bench
}

fn arith_decode(encoded ArithEncodedResult) []u8 {
	frequencies := encoded.frequencies
	mut total := 0
	for f in frequencies {
		total += f
	}
	data_size := total

	mut low_table := [256]int{}
	mut high_table := [256]int{}
	mut cum := 0
	for i := 0; i < 256; i++ {
		low_table[i] = cum
		cum += frequencies[i]
		high_table[i] = cum
	}

	mut result := []u8{len: data_size}
	mut input := new_bit_input_stream(encoded.data)

	mut value := u64(0)
	for _ in 0 .. 32 {
		value = (value << 1) | u64(input.read_bit())
	}

	mut low := u64(0)
	mut high := u64(0xFFFFFFFF)

	for j := 0; j < data_size; j++ {
		range_val := high - low + 1
		scaled := ((value - low + 1) * u64(total) - 1) / range_val

		mut symbol := 0
		for symbol < 255 && u64(high_table[symbol]) <= scaled {
			symbol++
		}

		result[j] = u8(symbol)

		high = low + (range_val * u64(high_table[symbol]) / u64(total)) - 1
		low = low + (range_val * u64(low_table[symbol]) / u64(total))

		for {
			if high < 0x80000000 {
			} else if low >= 0x80000000 {
				value -= 0x80000000
				low -= 0x80000000
				high -= 0x80000000
			} else if low >= 0x40000000 && high < 0xC0000000 {
				value -= 0x40000000
				low -= 0x40000000
				high -= 0x40000000
			} else {
				break
			}

			low <<= 1
			high = (high << 1) | 1
			value = (value << 1) | u64(input.read_bit())
		}
	}

	return result
}

pub fn (b ArithDecode) name() string {
	return 'Compress::ArithDecode'
}

pub fn (mut b ArithDecode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)

	mut encoder := new_arithencode() as ArithEncode
	encoder.size_val = b.size_val
	encoder.prepare()
	encoder.run(0)

	b.encoded = encoder.encoded
	b.result_val = 0
}

pub fn (mut b ArithDecode) run(iteration_id int) {
	b.decoded = arith_decode(b.encoded)
	b.result_val += u32(b.decoded.len)
}

pub fn (b ArithDecode) checksum() u32 {
	mut res := b.result_val
	if b.test_data.len == b.decoded.len {
		mut equal := true
		for i := 0; i < b.test_data.len; i++ {
			if b.test_data[i] != b.decoded[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}

struct LZWResult {
pub:
	data      []u8
	dict_size int
}

pub struct LZWEncode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	encoded    LZWResult
}

pub fn new_lzwencode() &benchmark.IBenchmark {
	mut bench := &LZWEncode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::LZWEncode')
		result_val:    0
		size_val:      helper.config_i64('Compress::LZWEncode', 'size')
	}
	return bench
}

fn lzw_encode(input []u8) LZWResult {
	if input.len == 0 {
		return LZWResult{[]u8{}, 256}
	}

	mut dict := map[string]int{}
	dict.reserve(4096)

	for i := 0; i < 256; i++ {
		dict[i.str()] = i
	}

	mut next_code := 256

	mut result := []u8{cap: input.len * 2}

	mut current := input[0].str()

	for i := 1; i < input.len; i++ {
		next_char := input[i].str()
		new_str := current + next_char

		if new_str in dict {
			current = new_str
		} else {
			code := dict[current]
			result << u8((code >> 8) & 0xFF)
			result << u8(code & 0xFF)

			dict[new_str] = next_code
			next_code++
			current = next_char
		}
	}

	code := dict[current]
	result << u8((code >> 8) & 0xFF)
	result << u8(code & 0xFF)

	return LZWResult{result, next_code}
}

pub fn (b LZWEncode) name() string {
	return 'Compress::LZWEncode'
}

pub fn (mut b LZWEncode) prepare() {
	b.test_data = generate_test_data(b.size_val)
	b.result_val = 0
}

pub fn (mut b LZWEncode) run(iteration_id int) {
	b.encoded = lzw_encode(b.test_data)
	b.result_val += u32(b.encoded.data.len)
}

pub fn (b LZWEncode) checksum() u32 {
	return b.result_val
}

pub struct LZWDecode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
	decoded    []u8
	encoded    LZWResult
}

pub fn new_lzwdecode() &benchmark.IBenchmark {
	mut bench := &LZWDecode{
		BaseBenchmark: benchmark.new_base_benchmark('Compress::LZWDecode')
		result_val:    0
		size_val:      helper.config_i64('Compress::LZWDecode', 'size')
	}
	return bench
}

fn lzw_decode(encoded LZWResult) []u8 {
	if encoded.data.len == 0 {
		return []u8{}
	}

	mut dict := []string{cap: 4096}
	for i := 0; i < 256; i++ {
		dict << i.str()
	}

	mut result := []u8{cap: encoded.data.len * 2}

	data := encoded.data
	mut pos := 0

	mut old_code := (int(data[pos]) << 8) | int(data[pos + 1])
	pos += 2

	mut old_str := dict[old_code]

	for c in old_str {
		result << u8(c)
	}

	mut next_code := 256

	for pos < data.len {
		new_code := (int(data[pos]) << 8) | int(data[pos + 1])
		pos += 2

		mut new_str := ''
		if new_code < dict.len {
			new_str = dict[new_code]
		} else if new_code == next_code {
			first_char := old_str[0].str()
			new_str = old_str + first_char
		} else {
			panic('Error decode')
		}

		for c in new_str {
			result << u8(c)
		}

		first_char := new_str[0].str()
		dict << old_str + first_char
		next_code++

		old_str = new_str
	}

	return result
}

pub fn (b LZWDecode) name() string {
	return 'Compress::LZWDecode'
}

pub fn (mut b LZWDecode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)

	mut encoder := new_lzwencode() as LZWEncode
	encoder.size_val = b.size_val
	encoder.prepare()
	encoder.run(0)

	b.encoded = encoder.encoded
	b.result_val = 0
}

pub fn (mut b LZWDecode) run(iteration_id int) {
	b.decoded = lzw_decode(b.encoded)
	b.result_val += u32(b.decoded.len)
}

pub fn (b LZWDecode) checksum() u32 {
	mut res := b.result_val
	if b.test_data.len == b.decoded.len {
		mut equal := true
		for i := 0; i < b.test_data.len; i++ {
			if b.test_data[i] != b.decoded[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 100000
		}
	}
	return res
}
