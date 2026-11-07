module base64_bench;

import benchmark;
import helper;
import std::io;
import std::core::mem;
import std::core::string;
import std::encoding::base64;

fn String preview(char[] s)
{
	if (s.len > 4)
	{
		return string::tformat("%s...", (String)s[:4]);
	}
	return (String)s[..];
}

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
	data.input_data[..] = 'a';

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

	String result = string::tformat(
		"encode %s to %s: %d",
		preview(data.input_data),
		preview(data.encoded_data),
		data.result_val
	);
	return helper::helper_checksum_string(result);
}

fn void base64_encode_cleanup(Benchmark* self)
{
	Base64EncodeData* data = (Base64EncodeData*)self.data;
	free(data.input_data);
	free(data.encoded_data);
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
	input_data[..] = 'a';

	data.encoded_data = base64::encode(mem, input_data);
	data.decoded_data = base64::decode(mem, data.encoded_data) ?? { };

	data.result_val = 0;
	free(input_data);
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

	String result = string::tformat(
		"decode %s to %s: %d",
		preview(data.encoded_data),
		preview(data.decoded_data),
		data.result_val
	);
	return helper::helper_checksum_string(result);
}

fn void base64_decode_cleanup(Benchmark* self)
{
	Base64DecodeData* data = (Base64DecodeData*)self.data;
	free(data.encoded_data);
	free(data.decoded_data);
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