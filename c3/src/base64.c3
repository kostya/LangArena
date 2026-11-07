module base64_bench;

import benchmark;
import helper;
import std::io;
import std::core::mem;
import std::core::string;
import std::encoding::base64;

struct Base64EncodeData
{
	char[] input_data;
	char[] encoded_data;
	uint result_val;
}

fn void base64_encode_prepare(Benchmark* self)
{
	Base64EncodeData* data = (Base64EncodeData*)self.data;

	long n = helper::helper_config_i64(self.name, "size");
	if (n <= 0) n = 100;

	data.input_data = mem::new_array(char, (usz)n);
	mem::set(data.input_data.ptr, 'a', (usz)n);

	data.encoded_data = base64::encode(mem, data.input_data);
	data.result_val = 0;
}

fn void base64_encode_run(Benchmark* self, int iteration_id)
{
	Base64EncodeData* data = (Base64EncodeData*)self.data;
	free(data.encoded_data);
	data.encoded_data = base64::encode(mem, data.input_data);
	data.result_val += (uint)data.encoded_data.len;
}

fn uint base64_encode_checksum(Benchmark* self)
{
	Base64EncodeData* data = (Base64EncodeData*)self.data;

	char[256] result_str;
	char[8] input_buf   = { };
	char[8] encoded_buf = { };

	if (data.input_data.len > 4)
	{
		mem::copy(&input_buf, data.input_data.ptr, 4);
		input_buf[4] = '.';
		input_buf[5] = '.';
		input_buf[6] = '.';
	}
	else
	{
		mem::copy(&input_buf, data.input_data.ptr, data.input_data.len);
	}

	if (data.encoded_data.len > 4)
	{
		mem::copy(&encoded_buf, data.encoded_data.ptr, 4);
		encoded_buf[4] = '.';
		encoded_buf[5] = '.';
		encoded_buf[6] = '.';
	}
	else
	{
		mem::copy(&encoded_buf, data.encoded_data.ptr, data.encoded_data.len);
	}

	String result = string::tformat("encode %s to %s: %d", (ZString)&input_buf, (ZString)&encoded_buf, data.result_val);
	return helper::helper_checksum_string(result);
}

fn void base64_encode_cleanup(Benchmark* self)
{
	Base64EncodeData* data = (Base64EncodeData*)self.data;
	mem::free(data.input_data.ptr);
	mem::free(data.encoded_data.ptr);
}

fn Benchmark* base64_encode_create() @cname("Base64Encode_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Base64::Encode");

	Base64EncodeData* data = mem::new(Base64EncodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&base64_encode_prepare;
	bench.run = (RunFn)&base64_encode_run;
	bench.checksum = (ChecksumFn)&base64_encode_checksum;
	bench.cleanup = (CleanupFn)&base64_encode_cleanup;

	return bench;
}

struct Base64DecodeData
{
	char[] encoded_data;
	char[] decoded_data;
	uint result_val;
}

fn void base64_decode_prepare(Benchmark* self)
{
	Base64DecodeData* data = (Base64DecodeData*)self.data;

	long n = helper::helper_config_i64(self.name, "size");
	if (n <= 0) n = 100;

	char[] input_data = mem::alloc_array(char, (usz)n);
	mem::set(input_data.ptr, 'a', (usz)n);

	data.encoded_data = base64::encode(mem, input_data);

	char[]? decoded_opt = base64::decode(mem, data.encoded_data);
	if (catch err = decoded_opt)
	{
		data.decoded_data = { };
	}
	else
	{
		data.decoded_data = decoded_opt;
	}

	data.result_val = 0;
	mem::free(input_data.ptr);
}

fn void base64_decode_run(Benchmark* self, int iteration_id)
{
	Base64DecodeData* data = (Base64DecodeData*)self.data;
	free(data.decoded_data);
	data.decoded_data = base64::decode(mem, data.encoded_data) ?? { };
	data.result_val += (uint)data.decoded_data.len;
}

fn uint base64_decode_checksum(Benchmark* self)
{
	Base64DecodeData* data = (Base64DecodeData*)self.data;

	char[8] encoded_buf = { };
	char[8] decoded_buf = { };

	if (data.encoded_data.len > 4)
	{
		mem::copy(&encoded_buf, data.encoded_data.ptr, 4);
		encoded_buf[4] = '.';
		encoded_buf[5] = '.';
		encoded_buf[6] = '.';
	}
	else
	{
		mem::copy(&encoded_buf, data.encoded_data.ptr, data.encoded_data.len);
	}

	if (data.decoded_data.len > 4)
	{
		mem::copy(&decoded_buf, data.decoded_data.ptr, 4);
		decoded_buf[4] = '.';
		decoded_buf[5] = '.';
		decoded_buf[6] = '.';
	}
	else
	{
		mem::copy(&decoded_buf, data.decoded_data.ptr, data.decoded_data.len);
	}

	String result = string::tformat(
		"decode %s to %s: %d",
		(ZString)&encoded_buf,
		(ZString)&decoded_buf,
		data.result_val
	);
	return helper::helper_checksum_string(result);
}

fn void base64_decode_cleanup(Benchmark* self)
{
	Base64DecodeData* data = (Base64DecodeData*)self.data;
	mem::free(data.encoded_data.ptr);
	mem::free(data.decoded_data.ptr);
}

fn Benchmark* base64_decode_create() @cname("Base64Decode_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Base64::Decode");

	Base64DecodeData* data = mem::new(Base64DecodeData);

	bench.data = data;
	bench.prepare = (PrepareFn)&base64_decode_prepare;
	bench.run = (RunFn)&base64_decode_run;
	bench.checksum = (ChecksumFn)&base64_decode_checksum;
	bench.cleanup = (CleanupFn)&base64_decode_cleanup;

	return bench;
}