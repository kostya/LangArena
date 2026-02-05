module compression

import benchmark

struct BWTResult {
pub:
	transformed  []u8
	original_idx int
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
pub:
	data      []u8
	bit_count int
}

struct CompressedData {
pub:
	bwt_result         BWTResult
	frequencies        []int
	encoded_bits       []u8
	original_bit_count int
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

fn huffman_encode(data []u8, huffman_codes HuffmanCodes) EncodedResult {
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

	return EncodedResult{result, total_bits}
}

fn huffman_decode(encoded []u8, root &HuffmanNode, bit_count int) []u8 {
	mut result := []u8{cap: bit_count / 4 + 1}
	mut current_node := unsafe { root }
	mut bits_processed := 0
	mut byte_index := 0

	for bits_processed < bit_count && byte_index < encoded.len {
		byte_val := encoded[byte_index]
		byte_index++

		if bits_processed + 8 <= bit_count {

			for bit_pos := 7; bit_pos >= 0; bit_pos-- {
				bit := ((byte_val >> bit_pos) & 1) == 1
				current_node = if bit {
					unsafe { current_node.right }
				} else {
					unsafe { current_node.left }
				}

				if current_node.is_leaf {
					result << current_node.byte_val
					current_node = unsafe { root }
				}
			}
			bits_processed += 8
		} else {

			for bit_pos := 7; bit_pos >= 0 && bits_processed < bit_count; bit_pos-- {
				bit := ((byte_val >> bit_pos) & 1) == 1
				current_node = if bit {
					unsafe { current_node.right }
				} else {
					unsafe { current_node.left }
				}
				bits_processed++

				if current_node.is_leaf {
					result << current_node.byte_val
					current_node = unsafe { root }
				}
			}
		}
	}

	return result
}

fn compress(data []u8) CompressedData {
	bwt_result := bwt_transform(data)

	mut frequencies := []int{len: 256, init: 0}
	for b in bwt_result.transformed {
		frequencies[b]++
	}

	huffman_tree := build_huffman_tree(frequencies)

	mut huffman_codes := HuffmanCodes{
		code_lengths: []int{len: 256, init: 0}
		codes:        []int{len: 256, init: 0}
	}
	build_huffman_codes(huffman_tree, u32(0), 0, mut huffman_codes)

	encoded := huffman_encode(bwt_result.transformed, huffman_codes)

	return CompressedData{
		bwt_result:         bwt_result
		frequencies:        frequencies
		encoded_bits:       encoded.data
		original_bit_count: encoded.bit_count
	}
}

fn decompress(compressed CompressedData) []u8 {

	huffman_tree := build_huffman_tree(compressed.frequencies)

	decoded := huffman_decode(compressed.encoded_bits, huffman_tree, compressed.original_bit_count)

	bwt_result := BWTResult{decoded, compressed.bwt_result.original_idx}
	return bwt_inverse(bwt_result)
}

pub struct BWTHuffEncode {
	benchmark.BaseBenchmark
mut:
	result_val u32
	size_val   i64
	test_data  []u8
}

pub fn new_bwthuffencode() &benchmark.IBenchmark {
	mut bench := &BWTHuffEncode{
		BaseBenchmark: benchmark.new_base_benchmark('BWTHuffEncode')
		result_val:    0
		size_val:      0
	}
	return bench
}

pub fn (b BWTHuffEncode) name() string {
	return 'BWTHuffEncode'
}

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

pub fn (mut b BWTHuffEncode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)
}

pub fn (mut b BWTHuffEncode) run(iteration_id int) {
	_ = iteration_id
	compressed := compress(b.test_data)
	b.result_val += u32(compressed.encoded_bits.len)
}

pub fn (b BWTHuffEncode) checksum() u32 {
	return b.result_val
}

pub struct BWTHuffDecode {
	benchmark.BaseBenchmark
mut:
	result_val      u32
	size_val        i64
	test_data       []u8
	compressed_data CompressedData
	decompressed    []u8
}

pub fn new_bwthuffdecode() &benchmark.IBenchmark {
	mut bench := &BWTHuffDecode{
		BaseBenchmark: benchmark.new_base_benchmark('BWTHuffDecode')
		result_val:    0
		size_val:      0
	}
	return bench
}

pub fn (b BWTHuffDecode) name() string {
	return 'BWTHuffDecode'
}

pub fn (mut b BWTHuffDecode) prepare() {
	b.size_val = b.BaseBenchmark.config_i64('size')
	b.test_data = generate_test_data(b.size_val)
	b.compressed_data = compress(b.test_data)
}

pub fn (mut b BWTHuffDecode) run(iteration_id int) {
	_ = iteration_id
	b.decompressed = decompress(b.compressed_data)
	b.result_val += u32(b.decompressed.len)
}

pub fn (b BWTHuffDecode) checksum() u32 {
	mut res := b.result_val
	if b.test_data.len == b.decompressed.len {
		mut equal := true
		for i in 0 .. b.test_data.len {
			if b.test_data[i] != b.decompressed[i] {
				equal = false
				break
			}
		}
		if equal {
			res += 1000000
		}
	}
	return res
}