module compress;

import benchmark;
import helper;
import std::io;
import std::core::mem;
import std::core::string;
import std::collections::map;
import std::sort;

fn char[] generate_test_data(long size)
{
	String pattern  = "ABRACADABRA";
	usz pattern_len = pattern.len;

	char* data = mem::alloc_array(char, (usz)size);

	for (long i = 0; i < size; i++)
	{
		data[i] = pattern[(usz)i % pattern_len];
	}

	return data[:(usz)size];
}

struct BWTResult
{
	char[] transformed;
	usz original_idx;
}

struct Pair
{
	int first;
	int second;
}

fn BWTResult bwt_transform(char[] input)
{
	BWTResult result = { };

	usz n = input.len;
	if (n == 0) return result;

	usz* sa = mem::new_array(usz, (sz)n);
	for (usz i = 0; i < n; i++)
	{
		sa[i] = i;
	}

	usz* temp_buffer       = mem::new_array(usz, (sz)n);
	usz[256] bucket_counts = { };

	for (usz i = 0; i < n; i++)
	{
		bucket_counts[(uint)(char)input[sa[i]]]++;
	}

	usz[256] bucket_starts;
	usz sum = 0;
	for (int i = 0; i < 256; i++)
	{
		bucket_starts[i] = sum;
		sum += bucket_counts[i];
	}

	for (usz i = 0; i < n; i++)
	{
		char c = input[sa[i]];
		temp_buffer[bucket_starts[(uint)(char)c]++] = sa[i];
	}
	mem::copy(sa, temp_buffer, (sz)n * usz::size);

	if (n > 1)
	{
		int* rank        = mem::new_array(int, (sz)n);
		int current_rank = 0;
		char prev_char   = input[sa[0]];

		for (usz i = 0; i < n; i++)
		{
			usz idx        = sa[i];
			char curr_char = input[idx];
			if (curr_char != prev_char)
			{
				current_rank++;
				prev_char = curr_char;
			}
			rank[idx] = current_rank;
		}

		usz k = 1;
		while (k < n)
		{
			Pair* pairs = mem::new_array(Pair, (sz)n);

			for (usz i = 0; i < n; i++)
			{
				pairs[i].first = rank[i];
				pairs[i].second = rank[(i + k) % n];
			}

			int* count = mem::new_array(int, (sz)n + 1);

			for (usz i = 0; i < n; i++)
			{
				count[pairs[sa[i]].second]++;
			}
			for (usz i = 1; i <= n; i++)
			{
				count[i] += count[i - 1];
			}

			mem::copy(temp_buffer, sa, (sz)n * usz::size);
			for (int i = (int)n - 1; i >= 0; i--)
			{
				int key = pairs[temp_buffer[i]].second;
				sa[--count[key]] = temp_buffer[i];
			}

			mem::set(count, 0, (sz)(n + 1) * int::size);

			for (usz i = 0; i < n; i++)
			{
				count[pairs[sa[i]].first]++;
			}
			for (usz i = 1; i <= n; i++)
			{
				count[i] += count[i - 1];
			}

			mem::copy(temp_buffer, sa, (sz)n * usz::size);
			for (int i = (int)n - 1; i >= 0; i--)
			{
				int key = pairs[temp_buffer[i]].first;
				sa[--count[key]] = temp_buffer[i];
			}

			int* new_rank = mem::new_array(int, (sz)n);
			new_rank[sa[0]] = 0;
			for (usz i = 1; i < n; i++)
			{
				Pair prev_pair = pairs[sa[i - 1]];
				Pair curr_pair = pairs[sa[i]];
				new_rank[sa[i]] = new_rank[sa[i - 1]]
					+ (prev_pair.first != curr_pair.first || prev_pair.second != curr_pair.second ? 1
					: 0);
			}

			mem::free(count);
			mem::free(pairs);
			mem::free(rank);
			rank = new_rank;
			k *= 2;
		}
		mem::free(rank);
	}

	char* transformed = mem::new_array(char, (sz)n);
	result.original_idx = 0;

	for (usz i = 0; i < n; i++)
	{
		usz suffix = sa[i];
		if (suffix == 0)
		{
			transformed[i] = input[n - 1];
			result.original_idx = i;
		}
		else
		{
			transformed[i] = input[suffix - 1];
		}
	}

	result.transformed = transformed[:n];

	mem::free(sa);
	mem::free(temp_buffer);

	return result;
}

struct BWTEncodeData
{
	long size_val;
	char[] test_data;
	uint result_val;
}

fn void bwt_encode_prepare(Benchmark* self)
{
	BWTEncodeData* data = (BWTEncodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.result_val = 0;
}

fn void bwt_encode_run(Benchmark* self, int iteration_id)
{
	BWTEncodeData* data = (BWTEncodeData*)self.data;
	BWTResult result    = bwt_transform(data.test_data);

	if (result.transformed.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)result.transformed.len);
		mem::free(result.transformed.ptr);
	}
}

fn uint bwt_encode_checksum(Benchmark* self)
{
	return ((BWTEncodeData*)self.data).result_val;
}

fn void bwt_encode_cleanup(Benchmark* self)
{
	BWTEncodeData* data = (BWTEncodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* bwt_encode_create() @cname("BWTEncode_create") @export
{
	Benchmark* bench    = benchmark::benchmark_create("Compress::BWTEncode");
	BWTEncodeData* data = mem::new(BWTEncodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&bwt_encode_prepare;
	bench.run = (RunFn)&bwt_encode_run;
	bench.checksum = (ChecksumFn)&bwt_encode_checksum;
	bench.cleanup = (CleanupFn)&bwt_encode_cleanup;

	return bench;
}

fn char[] bwt_inverse(BWTResult* bwt_result)
{
	char[] bwt = bwt_result.transformed;
	usz n      = bwt.len;

	if (n == 0) return { };

	int[256] counts = { };
	for (usz i = 0; i < n; i++)
	{
		counts[(uint)(char)bwt[i]]++;
	}

	int[256] positions;
	int total = 0;
	for (int i = 0; i < 256; i++)
	{
		positions[i] = total;
		total += counts[i];
	}

	usz* next            = mem::alloc_array(usz, (sz)n);
	int[256] temp_counts = { };

	for (usz i = 0; i < n; i++)
	{
		int byte_idx = (uint)(char)bwt[i];
		int pos      = positions[byte_idx] + temp_counts[byte_idx];
		next[pos] = i;
		temp_counts[byte_idx]++;
	}

	char* result = mem::alloc_array(char, (sz)n);
	usz idx      = bwt_result.original_idx;

	for (usz i = 0; i < n; i++)
	{
		idx = next[idx];
		result[i] = bwt[idx];
	}

	mem::free(next);
	return result[:n];
}

struct BWTDecodeData
{
	long size_val;
	char[] test_data;
	char[] inverted;
	BWTResult bwt_result;
	uint result_val;
}

fn void bwt_decode_prepare(Benchmark* self)
{
	BWTDecodeData* data = (BWTDecodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.bwt_result = bwt_transform(data.test_data);
	data.inverted = { };
	data.result_val = 0;
}

fn void bwt_decode_run(Benchmark* self, int iteration_id)
{
	BWTDecodeData* data = (BWTDecodeData*)self.data;

	mem::free(data.inverted.ptr);
	data.inverted = bwt_inverse(&data.bwt_result);

	if (data.inverted.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)data.inverted.len);
	}
}

fn uint bwt_decode_checksum(Benchmark* self)
{
	BWTDecodeData* data = (BWTDecodeData*)self.data;
	uint res            = data.result_val;

	if (data.inverted.len > 0 && data.inverted.len == data.test_data.len)
	{
		if (mem::equals(data.inverted.ptr, data.test_data.ptr, data.test_data.len))
		{
			res = (uint)(res + 100000);
		}
	}
	return res;
}

fn void bwt_decode_cleanup(Benchmark* self)
{
	BWTDecodeData* data = (BWTDecodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data.inverted.ptr);
	mem::free(data.bwt_result.transformed.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* bwt_decode_create() @cname("BWTDecode_create") @export
{
	Benchmark* bench    = benchmark::benchmark_create("Compress::BWTDecode");
	BWTDecodeData* data = mem::new(BWTDecodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&bwt_decode_prepare;
	bench.run = (RunFn)&bwt_decode_run;
	bench.checksum = (ChecksumFn)&bwt_decode_checksum;
	bench.cleanup = (CleanupFn)&bwt_decode_cleanup;

	return bench;
}

struct HuffmanNode
{
	int frequency;
	char byte_val;
	bool is_leaf;
	HuffmanNode* left;
	HuffmanNode* right;
}

struct HuffmanCodes
{
	int[256] code_lengths;
	int[256] codes;
}

struct EncodedResult
{
	char[] data;
	int bit_count;
	int[256] frequencies;
}

fn int compare_huffman_nodes(HuffmanNode* a, HuffmanNode* b)
{
	return a.frequency - b.frequency;
}

fn HuffmanNode* build_huffman_tree(int[256] frequencies)
{
	HuffmanNode** nodes = mem::alloc_array(HuffmanNode*, 256);
	int node_count      = 0;

	for (int i = 0; i < 256; i++)
	{
		if (frequencies[i] > 0)
		{
			HuffmanNode* node = mem::new(HuffmanNode);
			node.frequency = frequencies[i];
			node.byte_val = (char)i;
			node.is_leaf = true;
			nodes[node_count++] = node;
		}
	}

	if (node_count == 0)
	{
		mem::free(nodes);
		return null;
	}

	if (node_count == 1)
	{
		HuffmanNode* root = mem::new(HuffmanNode);
		root.frequency = nodes[0].frequency;
		root.is_leaf = false;
		root.left = nodes[0];

		root.right = mem::new(HuffmanNode);
		root.right.is_leaf = true;

		mem::free(nodes);
		return root;
	}

	sort::quicksort(nodes[:node_count], &compare_huffman_nodes);

	while (node_count > 1)
	{
		HuffmanNode* left  = nodes[0];
		HuffmanNode* right = nodes[1];

		HuffmanNode* parent = mem::new(HuffmanNode);
		parent.frequency = left.frequency + right.frequency;
		parent.is_leaf = false;
		parent.left = left;
		parent.right = right;

		nodes[0] = parent;
		for (int i = 1; i < node_count - 1; i++)
		{
			nodes[i] = nodes[i + 1];
		}
		node_count--;

		sort::quicksort(nodes[:node_count], &compare_huffman_nodes);
	}

	HuffmanNode* root = nodes[0];
	mem::free(nodes);
	return root;
}

fn void build_huffman_codes(HuffmanNode* node, int code, int length, HuffmanCodes* codes)
{
	if (!node) return;

	if (node.is_leaf)
	{
		int idx = (uint)(char)node.byte_val;
		codes.code_lengths[idx] = length;
		codes.codes[idx] = code;
	}
	else
	{
		if (node.left)
		{
			build_huffman_codes(node.left, code << 1, length + 1, codes);
		}
		if (node.right)
		{
			build_huffman_codes(node.right, (code << 1) | 1, length + 1, codes);
		}
	}
}

fn void free_huffman_tree(HuffmanNode* node)
{
	if (!node) return;
	if (!node.is_leaf)
	{
		free_huffman_tree(node.left);
		free_huffman_tree(node.right);
	}
	mem::free(node);
}

fn EncodedResult huffman_encode(char[] data, HuffmanCodes* codes, int[256] frequencies)
{
	EncodedResult result = { };
	if (data.len == 0) return result;

	mem::copy(&result.frequencies, &frequencies, 256 * int::size);

	usz max_size  = data.len * 2;
	char* buf     = mem::alloc_array(char, (sz)max_size);
	usz data_size = 0;

	char current_byte = 0;
	int bit_pos       = 0;

	for (usz i = 0; i < data.len; i++)
	{
		int idx    = (uint)(char)data[i];
		int code   = codes.codes[idx];
		int length = codes.code_lengths[idx];

		if (length <= 0) continue;

		for (int j = length - 1; j >= 0; j--)
		{
			if (code & (1 << j))
			{
				current_byte |= (char)(1 << (7 - bit_pos));
			}
			bit_pos++;
			result.bit_count++;

			if (bit_pos == 8)
			{
				if (data_size >= max_size)
				{
					max_size *= 2;
					buf = mem::realloc(buf, (sz)max_size);
				}
				buf[data_size++] = current_byte;
				current_byte = 0;
				bit_pos = 0;
			}
		}
	}

	if (bit_pos > 0)
	{
		if (data_size >= max_size)
		{
			max_size *= 2;
			buf = mem::realloc(buf, (sz)max_size);
		}
		buf[data_size++] = current_byte;
	}

	result.data = buf[:data_size];
	return result;
}

fn char[] huffman_decode(char[] encoded, HuffmanNode* root, int bit_count)
{
	if (!root || bit_count <= 0 || encoded.len == 0) return { };

	usz max_size              = (usz)bit_count;
	char* result              = mem::alloc_array(char, (sz)max_size);
	usz result_idx            = 0;
	HuffmanNode* current_node = root;
	int bits_processed        = 0;
	usz byte_index            = 0;

	while (bits_processed < bit_count && byte_index < encoded.len)
	{
		char byte_val = encoded[byte_index++];

		for (int bit_pos = 7; bit_pos >= 0 && bits_processed < bit_count; bit_pos--)
		{
			int bit = ((uint)(char)byte_val >> bit_pos) & 1;
			bits_processed++;

			current_node = bit != 0 ? current_node.right : current_node.left;
			if (!current_node) break;

			if (current_node.is_leaf)
			{
				result[result_idx++] = current_node.byte_val;
				current_node = root;
			}
		}
	}

	return result[:result_idx];
}

struct HuffEncodeData
{
	long size_val;
	char[] test_data;
	EncodedResult encoded;
	uint result_val;
}

fn void huff_encode_prepare(Benchmark* self)
{
	HuffEncodeData* data = (HuffEncodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.result_val = 0;
}

fn void huff_encode_run(Benchmark* self, int iteration_id)
{
	HuffEncodeData* data = (HuffEncodeData*)self.data;

	mem::free(data.encoded.data.ptr);
	data.encoded = (EncodedResult) { };

	int[256] frequencies = { };
	for (usz i = 0; i < data.test_data.len; i++)
	{
		frequencies[(uint)(char)data.test_data[i]]++;
	}

	HuffmanNode* tree = build_huffman_tree(frequencies);
	if (!tree) return;

	HuffmanCodes codes = { };
	build_huffman_codes(tree, 0, 0, &codes);

	data.encoded = huffman_encode(data.test_data, &codes, frequencies);

	if (data.encoded.data.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)data.encoded.data.len);
	}

	free_huffman_tree(tree);
}

fn uint huff_encode_checksum(Benchmark* self)
{
	return ((HuffEncodeData*)self.data).result_val;
}

fn void huff_encode_cleanup(Benchmark* self)
{
	HuffEncodeData* data = (HuffEncodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data.encoded.data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* huff_encode_create() @cname("HuffEncode_create") @export
{
	Benchmark* bench     = benchmark::benchmark_create("Compress::HuffEncode");
	HuffEncodeData* data = mem::new(HuffEncodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&huff_encode_prepare;
	bench.run = (RunFn)&huff_encode_run;
	bench.checksum = (ChecksumFn)&huff_encode_checksum;
	bench.cleanup = (CleanupFn)&huff_encode_cleanup;

	return bench;
}

struct HuffDecodeData
{
	long size_val;
	char[] test_data;
	char[] decoded;
	EncodedResult encoded;
	uint result_val;
}

fn void huff_decode_prepare(Benchmark* self)
{
	HuffDecodeData* data = (HuffDecodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.result_val = 0;
	data.decoded = { };

	int[256] frequencies = { };
	for (usz i = 0; i < data.test_data.len; i++)
	{
		frequencies[(uint)(char)data.test_data[i]]++;
	}

	HuffmanNode* tree = build_huffman_tree(frequencies);
	if (tree)
	{
		HuffmanCodes codes = { };
		build_huffman_codes(tree, 0, 0, &codes);
		data.encoded = huffman_encode(data.test_data, &codes, frequencies);
		free_huffman_tree(tree);
	}
}

fn void huff_decode_run(Benchmark* self, int iteration_id)
{
	HuffDecodeData* data = (HuffDecodeData*)self.data;

	HuffmanNode* tree = build_huffman_tree(data.encoded.frequencies);
	if (!tree) return;

	mem::free(data.decoded.ptr);
	data.decoded = huffman_decode(data.encoded.data, tree, data.encoded.bit_count);

	if (data.decoded.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)data.decoded.len);
	}

	free_huffman_tree(tree);
}

fn uint huff_decode_checksum(Benchmark* self)
{
	HuffDecodeData* data = (HuffDecodeData*)self.data;
	uint res             = data.result_val;

	if (data.decoded.len > 0 && data.decoded.len == data.test_data.len)
	{
		if (mem::equals(data.decoded.ptr, data.test_data.ptr, data.test_data.len))
		{
			res = (uint)(res + 100000);
		}
	}
	return res;
}

fn void huff_decode_cleanup(Benchmark* self)
{
	HuffDecodeData* data = (HuffDecodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data.decoded.ptr);
	mem::free(data.encoded.data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* huff_decode_create() @cname("HuffDecode_create") @export
{
	Benchmark* bench     = benchmark::benchmark_create("Compress::HuffDecode");
	HuffDecodeData* data = mem::new(HuffDecodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&huff_decode_prepare;
	bench.run = (RunFn)&huff_decode_run;
	bench.checksum = (ChecksumFn)&huff_decode_checksum;
	bench.cleanup = (CleanupFn)&huff_decode_cleanup;

	return bench;
}

struct ArithFreqTable
{
	int total;
	int[256] low;
	int[256] high;
}

fn ArithFreqTable* create_arith_freq_table(int[256] frequencies)
{
	ArithFreqTable* ft = mem::new(ArithFreqTable);
	ft.total = 0;
	for (int i = 0; i < 256; i++)
	{
		ft.total += frequencies[i];
	}

	int cum = 0;
	for (int i = 0; i < 256; i++)
	{
		ft.low[i] = cum;
		cum += frequencies[i];
		ft.high[i] = cum;
	}
	return ft;
}

struct BitOutputStream
{
	int buffer;
	int bit_pos;
	char* bytes;
	usz bytes_size;
	usz bytes_capacity;
	int bits_written;
}

fn BitOutputStream* bit_output_create()
{
	BitOutputStream* out = mem::new(BitOutputStream);
	out.bytes_capacity = 1024;
	out.bytes = mem::alloc_array(char, (sz)out.bytes_capacity);
	return out;
}

fn void bit_output_write_bit(BitOutputStream* out, int bit)
{
	if (!out) return;
	out.buffer = (out.buffer << 1) | (bit & 1);
	out.bit_pos++;
	out.bits_written++;

	if (out.bit_pos == 8)
	{
		if (out.bytes_size >= out.bytes_capacity)
		{
			out.bytes_capacity *= 2;
			out.bytes = mem::realloc(out.bytes, (sz)out.bytes_capacity);
		}
		out.bytes[out.bytes_size++] = (char)out.buffer;
		out.buffer = 0;
		out.bit_pos = 0;
	}
}

fn char[] bit_output_flush(BitOutputStream* out)
{
	if (!out) return { };

	if (out.bit_pos > 0)
	{
		out.buffer <<= (8 - out.bit_pos);
		if (out.bytes_size >= out.bytes_capacity)
		{
			out.bytes_capacity *= 2;
			out.bytes = mem::realloc(out.bytes, (sz)out.bytes_capacity);
		}
		out.bytes[out.bytes_size++] = (char)out.buffer;
	}

	char* result = mem::alloc_array(char, (sz)out.bytes_size);
	mem::copy(result, out.bytes, (sz)out.bytes_size);
	return result[:out.bytes_size];
}

fn void bit_output_free(BitOutputStream* out)
{
	if (out)
	{
		mem::free(out.bytes);
		mem::free(out);
	}
}

struct ArithEncodedResult
{
	char[] data;
	int bit_count;
	int[256] frequencies;
}

fn ArithEncodedResult arith_encode(char[] data)
{
	ArithEncodedResult result = { };
	if (data.len == 0) return result;

	int[256] frequencies = { };
	for (usz i = 0; i < data.len; i++)
	{
		frequencies[(uint)(char)data[i]]++;
	}

	ArithFreqTable* freq_table = create_arith_freq_table(frequencies);
	if (!freq_table) return result;

	ulong low               = 0;
	ulong high              = 0xFFFFFFFF;
	int pending             = 0;
	BitOutputStream* output = bit_output_create();
	if (!output)
	{
		mem::free(freq_table);
		return result;
	}

	for (usz i = 0; i < data.len; i++)
	{
		int idx     = (uint)(char)data[i];
		ulong range = high - low + 1;

		high = low + (range * (ulong)freq_table.high[idx] / (ulong)freq_table.total) - 1;
		low = low + (range * (ulong)freq_table.low[idx] / (ulong)freq_table.total);

		while (true)
		{
			if (high < 0x80000000)
			{
				bit_output_write_bit(output, 0);
				for (int j = 0; j < pending; j++)
				{
					bit_output_write_bit(output, 1);
				}
				pending = 0;
			}
			else if (low >= 0x80000000)
			{
				bit_output_write_bit(output, 1);
				for (int j = 0; j < pending; j++)
				{
					bit_output_write_bit(output, 0);
				}
				pending = 0;
				low -= 0x80000000;
				high -= 0x80000000;
			}
			else if (low >= 0x40000000 && high < 0xC0000000)
			{
				pending++;
				low -= 0x40000000;
				high -= 0x40000000;
			}
			else
			{
				break;
			}
			low <<= 1;
			high = (high << 1) | 1;
			high &= 0xFFFFFFFF;
		}
	}

	pending++;
	if (low < 0x40000000)
	{
		bit_output_write_bit(output, 0);
		for (int j = 0; j < pending; j++)
		{
			bit_output_write_bit(output, 1);
		}
	}
	else
	{
		bit_output_write_bit(output, 1);
		for (int j = 0; j < pending; j++)
		{
			bit_output_write_bit(output, 0);
		}
	}

	result.data = bit_output_flush(output);
	result.bit_count = output.bits_written;
	mem::copy(&result.frequencies, &frequencies, 256 * int::size);

	bit_output_free(output);
	mem::free(freq_table);
	return result;
}

struct ArithEncodeData
{
	long size_val;
	char[] test_data;
	uint result_val;
}

fn void arith_encode_prepare(Benchmark* self)
{
	ArithEncodeData* data = (ArithEncodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	if (data.size_val == 0)
	{
		data.size_val = 1000;
	}
	mem::free(data.test_data.ptr);
	data.test_data = generate_test_data(data.size_val);
	data.result_val = 0;
}

fn void arith_encode_run(Benchmark* self, int iteration_id)
{
	ArithEncodeData* data = (ArithEncodeData*)self.data;
	if (data.test_data.len == 0) return;

	ArithEncodedResult result = arith_encode(data.test_data);
	if (result.data.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)result.data.len);
		mem::free(result.data.ptr);
	}
}

fn uint arith_encode_checksum(Benchmark* self)
{
	return ((ArithEncodeData*)self.data).result_val;
}

fn void arith_encode_cleanup(Benchmark* self)
{
	ArithEncodeData* data = (ArithEncodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* arith_encode_create() @cname("ArithEncode_create") @export
{
	Benchmark* bench      = benchmark::benchmark_create("Compress::ArithEncode");
	ArithEncodeData* data = mem::new(ArithEncodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&arith_encode_prepare;
	bench.run = (RunFn)&arith_encode_run;
	bench.checksum = (ChecksumFn)&arith_encode_checksum;
	bench.cleanup = (CleanupFn)&arith_encode_cleanup;

	return bench;
}

struct BitInputStream
{
	char* bytes;
	usz bytes_size;
	usz byte_pos;
	int bit_pos;
	char current_byte;
}

fn void bit_input_init(BitInputStream* input, char[] data)
{
	input.bytes = data.ptr;
	input.bytes_size = data.len;
	input.byte_pos = 0;
	input.bit_pos = 0;
	input.current_byte = data.len > 0 ? data[0] : 0;
}

fn int bit_input_read_bit(BitInputStream* input)
{
	if (input.bit_pos == 8)
	{
		input.byte_pos++;
		input.bit_pos = 0;
		input.current_byte = input.byte_pos < input.bytes_size ? input.bytes[input.byte_pos] : 0;
	}
	int bit = ((uint)(char)input.current_byte >> (7 - input.bit_pos)) & 1;
	input.bit_pos++;
	return bit;
}

fn char[] arith_decode(ArithEncodedResult* encoded)
{
	if (encoded.data.len == 0) return { };

	int total = 0;
	for (int i = 0; i < 256; i++)
	{
		total += encoded.frequencies[i];
	}
	if (total == 0) return { };

	int[256] low_table;
	int[256] high_table;
	int cum = 0;
	for (int i = 0; i < 256; i++)
	{
		low_table[i] = cum;
		cum += encoded.frequencies[i];
		high_table[i] = cum;
	}

	char* result = mem::alloc_array(char, (usz)total);
	BitInputStream input;
	bit_input_init(&input, encoded.data);

	ulong value = 0;
	for (int i = 0; i < 32; i++)
	{
		value = (value << 1) | (ulong)bit_input_read_bit(&input);
	}

	ulong low  = 0;
	ulong high = 0xFFFFFFFF;

	for (int j = 0; j < total; j++)
	{
		ulong range  = high - low + 1;
		ulong scaled = ((value - low + 1) * (ulong)total - 1) / range;

		int left  = 0;
		int right = 256;
		while (left < right)
		{
			int mid = (left + right) / 2;
			if ((ulong)high_table[mid] <= scaled)
			{
				left = mid + 1;
			}
			else
			{
				right = mid;
			}
		}
		int symbol = left;

		result[j] = (char)symbol;

		high = low + (range * (ulong)high_table[symbol] / (ulong)total) - 1;
		low = low + (range * (ulong)low_table[symbol] / (ulong)total);

		while (true)
		{
			if (high < 0x80000000)
			{
			}
			else if (low >= 0x80000000)
			{
				value -= 0x80000000;
				low -= 0x80000000;
				high -= 0x80000000;
			}
			else if (low >= 0x40000000 && high < 0xC0000000)
			{
				value -= 0x40000000;
				low -= 0x40000000;
				high -= 0x40000000;
			}
			else
			{
				break;
			}
			low <<= 1;
			high = (high << 1) | 1;
			value = (value << 1) | (ulong)bit_input_read_bit(&input);
		}
	}

	return result[:(usz)total];
}

struct ArithDecodeData
{
	long size_val;
	char[] test_data;
	char[] decoded;
	ArithEncodedResult encoded;
	uint result_val;
}

fn void arith_decode_prepare(Benchmark* self)
{
	ArithDecodeData* data = (ArithDecodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	if (data.size_val == 0)
	{
		data.size_val = 1000;
	}
	mem::free(data.test_data.ptr);
	data.test_data = generate_test_data(data.size_val);
	mem::free(data.encoded.data.ptr);
	data.encoded = arith_encode(data.test_data);
	data.decoded = { };
	data.result_val = 0;
}

fn void arith_decode_run(Benchmark* self, int iteration_id)
{
	ArithDecodeData* data = (ArithDecodeData*)self.data;
	mem::free(data.decoded.ptr);
	data.decoded = arith_decode(&data.encoded);

	if (data.decoded.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)data.decoded.len);
	}
}

fn uint arith_decode_checksum(Benchmark* self)
{
	ArithDecodeData* data = (ArithDecodeData*)self.data;
	uint res              = data.result_val;

	if (data.decoded.len > 0 && data.decoded.len == data.test_data.len)
	{
		if (mem::equals(data.decoded.ptr, data.test_data.ptr, data.test_data.len))
		{
			res = (uint)(res + 100000);
		}
	}
	return res;
}

fn void arith_decode_cleanup(Benchmark* self)
{
	ArithDecodeData* data = (ArithDecodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data.decoded.ptr);
	mem::free(data.encoded.data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* arith_decode_create() @cname("ArithDecode_create") @export
{
	Benchmark* bench      = benchmark::benchmark_create("Compress::ArithDecode");
	ArithDecodeData* data = mem::new(ArithDecodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&arith_decode_prepare;
	bench.run = (RunFn)&arith_decode_run;
	bench.checksum = (ChecksumFn)&arith_decode_checksum;
	bench.cleanup = (CleanupFn)&arith_decode_cleanup;

	return bench;
}

alias LzwDict = HashMap{String, int};

struct LZWResult
{
	char[] data;
	int dict_size;
}

fn LZWResult lzw_encode(char[] input)
{
	LZWResult result = { };
	result.dict_size = 256;

	if (input.len == 0) return result;

	DynamicArenaAllocator arena;
	arena.init(mem, 65536);
	defer arena.free();

	LzwDict dict;
	dict.init(&arena, 4096);

	for (int i = 0; i < 256; i++)
	{
		char[2] key_buf;
		key_buf[0] = (char)i;
		key_buf[1] = 0;
		dict.set(((ZString)&key_buf).str_view(), i);
	}

	int next_code = 256;

	usz cur_start = 0;
	usz cur_len   = 1;

	usz max_size  = input.len * 2;
	char* buf     = mem::alloc_array(char, (sz)max_size);
	usz data_size = 0;

	for (usz i = 1; i < input.len; i++)
	{
		char[4096] temp_buf;
		String new_key;
		if (cur_len + 1 <= 4096)
		{
			mem::copy(&temp_buf, &input[cur_start], (sz)cur_len);
			temp_buf[cur_len] = input[i];
			new_key = ((ZString)&temp_buf).str_view()[:cur_len + 1];
		}
		else
		{
			char* new_str = alloc::alloc_array(&arena, char, (sz)cur_len + 1);
			mem::copy(new_str, &input[cur_start], (sz)cur_len);
			new_str[cur_len] = input[i];
			new_key = ((ZString)new_str).str_view();
		}

		int? entry = dict.get(new_key);

		if (try val = entry)
		{
			cur_len++;
		}
		else
		{
			int code = dict.get((String)input[cur_start:cur_len]) ?? 0;

			if (data_size + 2 > max_size)
			{
				max_size *= 2;
				buf = mem::realloc(buf, (sz)max_size);
			}
			buf[data_size++] = (char)((code >> 8) & 0xFF);
			buf[data_size++] = (char)(code & 0xFF);

			char* persist_key = alloc::alloc_array(&arena, char, new_key.len + 1);
			mem::copy(persist_key, (char*)new_key, new_key.len);
			persist_key[new_key.len] = 0;
			dict.set(((ZString)persist_key).str_view(), next_code++);

			cur_start = i;
			cur_len = 1;
		}
	}

	int last_code = dict.get((String)input[cur_start:cur_len]) ?? 0;
	if (data_size + 2 > max_size)
	{
		max_size *= 2;
		buf = mem::realloc(buf, (sz)max_size);
	}
	buf[data_size++] = (char)((last_code >> 8) & 0xFF);
	buf[data_size++] = (char)(last_code & 0xFF);

	result.data = buf[:data_size];
	result.dict_size = next_code;

	dict.free();
	return result;
}

struct LZWEncodeData
{
	long size_val;
	char[] test_data;
	uint result_val;
}

fn void lzw_encode_prepare(Benchmark* self)
{
	LZWEncodeData* data = (LZWEncodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.result_val = 0;
}

fn void lzw_encode_run(Benchmark* self, int iteration_id)
{
	LZWEncodeData* data = (LZWEncodeData*)self.data;
	LZWResult result    = lzw_encode(data.test_data);

	if (result.data.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)result.data.len);
		mem::free(result.data.ptr);
	}
}

fn uint lzw_encode_checksum(Benchmark* self)
{
	return ((LZWEncodeData*)self.data).result_val;
}

fn void lzw_encode_cleanup(Benchmark* self)
{
	LZWEncodeData* data = (LZWEncodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* lzw_encode_create() @cname("LZWEncode_create") @export
{
	Benchmark* bench    = benchmark::benchmark_create("Compress::LZWEncode");
	LZWEncodeData* data = mem::new(LZWEncodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&lzw_encode_prepare;
	bench.run = (RunFn)&lzw_encode_run;
	bench.checksum = (ChecksumFn)&lzw_encode_checksum;
	bench.cleanup = (CleanupFn)&lzw_encode_cleanup;

	return bench;
}

struct LZWDecodeData
{
	long size_val;
	char[] test_data;
	char[] decoded;
	LZWResult encoded;
	uint result_val;
}

fn char[] lzw_decode(LZWResult* encoded)
{
	if (encoded.data.len == 0) return { };

	DynamicArenaAllocator arena;
	arena.init(mem, 65536);
	defer arena.free();

	usz dict_capacity = 4096;
	char** dict       = alloc::alloc_array(&arena, char*, (sz)dict_capacity);
	usz* dict_len     = alloc::alloc_array(&arena, usz, (sz)dict_capacity);
	usz dict_size     = 256;

	for (int i = 0; i < 256; i++)
	{
		char* entry = alloc::alloc_array(&arena, char, 1);
		entry[0] = (char)i;
		dict[i] = entry;
		dict_len[i] = 1;
	}

	usz result_capacity = encoded.data.len * 2;
	char* result        = mem::alloc_array(char, (sz)result_capacity);
	usz result_pos      = 0;

	char* data = encoded.data.ptr;
	usz pos    = 0;

	if (pos + 1 >= encoded.data.len)
	{
		mem::free(result);
		return { };
	}

	int old_code = ((uint)(char)data[pos] << 8) | (uint)(char)data[pos + 1];
	pos += 2;

	if (old_code < 0 || old_code >= (int)dict_size)
	{
		mem::free(result);
		return { };
	}

	usz old_len   = dict_len[old_code];
	char* old_str = dict[old_code];

	if (result_pos + old_len >= result_capacity)
	{
		result_capacity *= 2;
		result = mem::realloc(result, (sz)result_capacity);
	}
	mem::copy(result + result_pos, old_str, (sz)old_len);
	result_pos += old_len;

	int next_code = 256;

	while (pos + 1 < encoded.data.len)
	{
		int new_code = ((uint)(char)data[pos] << 8) | (uint)(char)data[pos + 1];
		pos += 2;

		char* new_str;
		usz new_len;
		if (new_code >= 0 && new_code < (int)dict_size)
		{
			new_str = dict[new_code];
			new_len = dict_len[new_code];
		}
		else if (new_code == next_code)
		{
			new_len = old_len + 1;
			new_str = alloc::alloc_array(&arena, char, (sz)new_len);
			mem::copy(new_str, old_str, (sz)old_len);
			new_str[old_len] = old_str[0];
		}
		else
		{
			mem::free(result);
			return { };
		}

		if (result_pos + new_len >= result_capacity)
		{
			result_capacity *= 2;
			result = mem::realloc(result, (sz)result_capacity);
		}
		mem::copy(result + result_pos, new_str, (sz)new_len);
		result_pos += new_len;

		usz entry_len = old_len + 1;
		char* entry   = alloc::alloc_array(&arena, char, (sz)entry_len);
		mem::copy(entry, old_str, (sz)old_len);
		entry[old_len] = new_str[0];

		if (dict_size >= dict_capacity)
		{
			dict_capacity *= 2;
			dict = alloc::realloc(&arena, dict, (sz)dict_capacity * void*::size);
			dict_len = alloc::realloc(&arena, dict_len, (sz)dict_capacity * usz::size);
		}
		dict[dict_size] = entry;
		dict_len[dict_size] = entry_len;
		dict_size++;

		next_code++;
		old_code = new_code;
		old_str = new_str;
		old_len = new_len;
	}

	return result[:result_pos];
}

fn void lzw_decode_prepare(Benchmark* self)
{
	LZWDecodeData* data = (LZWDecodeData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	data.test_data = generate_test_data(data.size_val);
	data.encoded = lzw_encode(data.test_data);
	data.decoded = { };
	data.result_val = 0;
}

fn void lzw_decode_run(Benchmark* self, int iteration_id)
{
	LZWDecodeData* data = (LZWDecodeData*)self.data;

	mem::free(data.decoded.ptr);
	data.decoded = lzw_decode(&data.encoded);

	if (data.decoded.len > 0)
	{
		data.result_val = (uint)(data.result_val + (uint)data.decoded.len);
	}
}

fn uint lzw_decode_checksum(Benchmark* self)
{
	LZWDecodeData* data = (LZWDecodeData*)self.data;
	uint res            = data.result_val;

	if (data.decoded.len > 0 && data.decoded.len == data.test_data.len)
	{
		if (mem::equals(data.decoded.ptr, data.test_data.ptr, data.test_data.len))
		{
			res = (uint)(res + 100000);
		}
	}
	return res;
}

fn void lzw_decode_cleanup(Benchmark* self)
{
	LZWDecodeData* data = (LZWDecodeData*)self.data;
	mem::free(data.test_data.ptr);
	mem::free(data.decoded.ptr);
	mem::free(data.encoded.data.ptr);
	mem::free(data);
	self.data = null;
}

fn Benchmark* lzw_decode_create() @cname("LZWDecode_create") @export
{
	Benchmark* bench    = benchmark::benchmark_create("Compress::LZWDecode");
	LZWDecodeData* data = mem::new(LZWDecodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&lzw_decode_prepare;
	bench.run = (RunFn)&lzw_decode_run;
	bench.checksum = (ChecksumFn)&lzw_decode_checksum;
	bench.cleanup = (CleanupFn)&lzw_decode_cleanup;

	return bench;
}