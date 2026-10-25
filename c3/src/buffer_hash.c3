module hash_bench;

import benchmark;
import helper;
import std::io;
import std::core::mem;
import std::core::string;

struct BufferHashBaseData
{
	char* data;
	long size_val;
	uint result_val;
}

fn void buffer_hash_base_prepare(Benchmark* self, String bench_name, BufferHashBaseData* data)
{
	data.size_val = helper::helper_config_i64(bench_name, "size");
	if (data.size_val <= 0) data.size_val = 1000000;

	data.data = mem::alloc_array(char, (usz)data.size_val);

	for (long i = 0; i < data.size_val; i++)
	{
		data.data[i] = (char)helper::helper_next_int(256);
	}

	data.result_val = 0;
}

fn void buffer_hash_base_cleanup(BufferHashBaseData* data)
{
	if (data.data)
	{
		mem::free(data.data);
		data.data = null;
	}
}

struct BufferHashSHA256Data
{
	BufferHashBaseData base;
}

fn uint buffer_hash_sha256_digest(char[] data)
{
	uint[8] hashes = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };

	for (usz i = 0; i < data.len; i++)
	{
		uint hash_idx = (uint)(i % 8);
		uint hash     = hashes[hash_idx];

		uint temp = (hash << 5) + hash;
		temp = temp + (uint)(char)data[i];
		hash = temp;

		temp = hash + (hash << 10);
		hashes[hash_idx] = temp ^ (hash >> 6);
	}

	char[32] result;
	for (int i = 0; i < 8; i++)
	{
		result[i * 4] = (char)(hashes[i] >> 24);
		result[i * 4 + 1] = (char)(hashes[i] >> 16);
		result[i * 4 + 2] = (char)(hashes[i] >> 8);
		result[i * 4 + 3] = (char)hashes[i];
	}

	return (uint)(char)result[0] | ((uint)(char)result[1] << 8) | ((uint)(char)result[2] << 16)
		| ((uint)(char)result[3] << 24);
}

fn void buffer_hash_sha256_prepare(Benchmark* self)
{
	BufferHashSHA256Data* data = (BufferHashSHA256Data*)self.data;
	buffer_hash_base_prepare(self, "Hash::SHA256", &data.base);
}

fn void buffer_hash_sha256_run(Benchmark* self, int iteration_id)
{
	BufferHashSHA256Data* data = (BufferHashSHA256Data*)self.data;
	data.base.data[helper::helper_next_int((uint)data.base.size_val)] = (char)helper::helper_next_int(256);
	uint hash_result = buffer_hash_sha256_digest(data.base.data[:data.base.size_val]);
	data.base.result_val = (uint)(data.base.result_val + hash_result);
}

fn uint buffer_hash_sha256_checksum(Benchmark* self)
{
	BufferHashSHA256Data* data = (BufferHashSHA256Data*)self.data;
	return data.base.result_val;
}

fn void buffer_hash_sha256_cleanup(Benchmark* self)
{
	BufferHashSHA256Data* data = (BufferHashSHA256Data*)self.data;
	buffer_hash_base_cleanup(&data.base);
}

fn Benchmark* buffer_hash_sha256_create() @cname("BufferHashSHA256_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Hash::SHA256");

	BufferHashSHA256Data* data = mem::new(BufferHashSHA256Data);

	bench.data = data;
	bench.prepare = (PrepareFn)&buffer_hash_sha256_prepare;
	bench.run = (RunFn)&buffer_hash_sha256_run;
	bench.checksum = (ChecksumFn)&buffer_hash_sha256_checksum;
	bench.cleanup = (CleanupFn)&buffer_hash_sha256_cleanup;

	return bench;
}

struct BufferHashCRC32Data
{
	BufferHashBaseData base;
}

fn uint buffer_hash_crc32_digest(char[] data)
{
	uint crc = 0xFFFFFFFFu;

	foreach (b : data)
	{
		crc = crc ^ (uint)(char)b;
		for (int j = 0; j < 8; j++)
		{
			if (crc & 1)
			{
				crc = (crc >> 1) ^ 0xEDB88320u;
			}
			else
			{
				crc = crc >> 1;
			}
		}
	}
	return crc ^ 0xFFFFFFFFu;
}

fn void buffer_hash_crc32_prepare(Benchmark* self)
{
	BufferHashCRC32Data* data = (BufferHashCRC32Data*)self.data;
	buffer_hash_base_prepare(self, "Hash::CRC32", &data.base);
}

fn void buffer_hash_crc32_run(Benchmark* self, int iteration_id)
{
	BufferHashCRC32Data* data = (BufferHashCRC32Data*)self.data;
	data.base.data[helper::helper_next_int((uint)data.base.size_val)] = (char)helper::helper_next_int(256);
	uint crc_result = buffer_hash_crc32_digest(data.base.data[:data.base.size_val]);
	data.base.result_val += crc_result;
}

fn uint buffer_hash_crc32_checksum(Benchmark* self)
{
	BufferHashCRC32Data* data = (BufferHashCRC32Data*)self.data;
	return data.base.result_val;
}

fn void buffer_hash_crc32_cleanup(Benchmark* self)
{
	BufferHashCRC32Data* data = (BufferHashCRC32Data*)self.data;
	buffer_hash_base_cleanup(&data.base);
}

fn Benchmark* buffer_hash_crc32_create() @cname("BufferHashCRC32_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Hash::CRC32");

	BufferHashCRC32Data* data = mem::new(BufferHashCRC32Data);

	bench.data = data;
	bench.prepare = (PrepareFn)&buffer_hash_crc32_prepare;
	bench.run = (RunFn)&buffer_hash_crc32_run;
	bench.checksum = (ChecksumFn)&buffer_hash_crc32_checksum;
	bench.cleanup = (CleanupFn)&buffer_hash_crc32_cleanup;

	return bench;
}