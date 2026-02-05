module base64decode

import benchmark
import helper
import encoding.base64 as b64

pub struct Base64Decode {
	benchmark.BaseBenchmark
	size_val i64
mut:
	encoded    string
	decoded    string
	result_val u32
}

pub fn new_base64decode() &benchmark.IBenchmark {
	size_val := helper.config_i64('Base64Decode', 'size')

	mut bench := &Base64Decode{
		BaseBenchmark: benchmark.new_base_benchmark('Base64Decode')
		size_val:      size_val
		encoded:       ''
		decoded:       ''
		result_val:    0
	}

	return bench
}

pub fn (b Base64Decode) name() string {
	return 'Base64Decode'
}

fn (mut b Base64Decode) prepare_for_checksum() {

	mut str := ''
	for _ in 0 .. b.size_val {
		str += 'a'
	}

	b.encoded = b64.encode(str.bytes())
	decoded_bytes := b64.decode(b.encoded)
	b.decoded = decoded_bytes.bytestr()
}

pub fn (mut b Base64Decode) run(iteration_id int) {
	_ = iteration_id

	decoded_bytes := b64.decode(b.encoded)
	decoded := decoded_bytes.bytestr()

	b.result_val += u32(decoded.len)
}

pub fn (b Base64Decode) checksum() u32 {

	mut desc := 'decode '

	if b.encoded.len > 4 {
		desc += b.encoded[..4] + '...'
	} else {
		desc += b.encoded
	}

	desc += ' to '

	if b.decoded.len > 4 {
		desc += b.decoded[..4] + '...'
	} else {
		desc += b.decoded
	}

	desc += ': ${b.result_val}'

	return helper.checksum_str(desc)
}

pub fn (mut b Base64Decode) prepare() {
	b.prepare_for_checksum()
	b.result_val = 0
}