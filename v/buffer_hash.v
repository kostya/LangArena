module buffer_hash

import benchmark
import helper

struct BufferHashBenchmark {
	benchmark.BaseBenchmark
pub mut:
	data []u8
mut:
	size_val   i64
	result_val u32
}

fn new_buffer_hash_benchmark(class_name string) BufferHashBenchmark {
	return BufferHashBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark(class_name)
		size_val:      0
		result_val:    0
	}
}

pub struct BufferHashSHA256 {
	BufferHashBenchmark
}

pub fn new_bufferhashsha256() &benchmark.IBenchmark {
	mut bench := &BufferHashSHA256{
		BufferHashBenchmark: new_buffer_hash_benchmark('BufferHashSHA256')
	}
	return bench
}

pub fn (b BufferHashSHA256) name() string {
	return 'BufferHashSHA256'
}

fn simple_sha256_digest(data []u8) []u8 {
	mut hashes := []u32{len: 8}
	hashes[0] = 0x6a09e667
	hashes[1] = 0xbb67ae85
	hashes[2] = 0x3c6ef372
	hashes[3] = 0xa54ff53a
	hashes[4] = 0x510e527f
	hashes[5] = 0x9b05688c
	hashes[6] = 0x1f83d9ab
	hashes[7] = 0x5be0cd19

	for i, val in data {
		hash_idx := i % 8
		mut hash := hashes[hash_idx]
		hash = ((hash << 5) + hash) + u32(val)
		hash = (hash + (hash << 10)) ^ (hash >> 6)
		hashes[hash_idx] = hash
	}

	mut result := []u8{len: 32}
	for i in 0 .. 8 {
		hash := hashes[i]
		result[i * 4] = u8(hash >> 24)
		result[i * 4 + 1] = u8(hash >> 16)
		result[i * 4 + 2] = u8(hash >> 8)
		result[i * 4 + 3] = u8(hash)
	}

	return result
}

pub fn (mut b BufferHashSHA256) prepare() {
	b.size_val = int(helper.config_i64('BufferHashSHA256', 'size'))
	b.data = []u8{len: int(b.size_val)}
	for i in 0 .. b.size_val {
		b.data[i] = u8(helper.next_int(256))
	}
}

pub fn (mut b BufferHashSHA256) run(iteration_id int) {
	_ = iteration_id
	bytes := simple_sha256_digest(b.data)

	mut hash_val := u32(0)
	hash_val |= u32(bytes[3]) << 24
	hash_val |= u32(bytes[2]) << 16
	hash_val |= u32(bytes[1]) << 8
	hash_val |= u32(bytes[0])

	b.result_val += hash_val
}

pub fn (b BufferHashSHA256) checksum() u32 {
	return b.result_val
}

pub struct BufferHashCRC32 {
	BufferHashBenchmark
}

pub fn new_bufferhashcrc32() &benchmark.IBenchmark {
	mut bench := &BufferHashCRC32{
		BufferHashBenchmark: new_buffer_hash_benchmark('BufferHashCRC32')
	}
	return bench
}

pub fn (b BufferHashCRC32) name() string {
	return 'BufferHashCRC32'
}

fn crc32(data []u8) u32 {
	mut crc := u32(0xFFFFFFFF)

	for byte in data {
		crc = crc ^ u32(byte)
		for _ in 0 .. 8 {
			if (crc & 1) == 1 {
				crc = (crc >> 1) ^ 0xEDB88320
			} else {
				crc = crc >> 1
			}
		}
	}
	return crc ^ 0xFFFFFFFF
}

pub fn (mut b BufferHashCRC32) prepare() {
	b.size_val = int(helper.config_i64('BufferHashCRC32', 'size'))
	b.data = []u8{len: int(b.size_val)}
	for i in 0 .. b.size_val {
		b.data[i] = u8(helper.next_int(256))
	}
}

pub fn (mut b BufferHashCRC32) run(iteration_id int) {
	_ = iteration_id
	hash_val := crc32(b.data)
	b.result_val += hash_val
}

pub fn (b BufferHashCRC32) checksum() u32 {
	return b.result_val
}
