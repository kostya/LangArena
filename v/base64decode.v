module base64decode

import benchmark
import helper
import encoding.base64 as b64
import strings

pub struct Base64Decode {
	benchmark.BaseBenchmark
	size_val i64
mut:
	encoded    string
	decoded    []byte
	result_val u32
}

pub fn new_base64decode() &benchmark.IBenchmark {
	size_val := helper.config_i64('Base64::Decode', 'size')

	mut bench := &Base64Decode{
		BaseBenchmark: benchmark.new_base_benchmark('Base64::Decode')
		size_val:      size_val
		encoded:       ''
		decoded:       []
		result_val:    0
	}

	return bench
}

pub fn (b Base64Decode) name() string {
	return 'Base64::Decode'
}

pub fn (mut b Base64Decode) run(iteration_id int) {
	b.decoded = b64.decode(b.encoded)
	b.result_val += u32(b.decoded.len)
}

pub fn (b Base64Decode) checksum() u32 {
	mut desc := 'decode '

	if b.encoded.len > 4 {
		desc += b.encoded[..4] + '...'
	} else {
		desc += b.encoded
	}

	desc += ' to '

	str3 := b.decoded[0..5].bytestr()

	if str3.len > 4 {
		desc += str3[..4] + '...'
	} else {
		desc += str3
	}

	desc += ': ${b.result_val}'

	return helper.checksum_str(desc)
}

pub fn (mut b Base64Decode) prepare() {
	mut str := strings.repeat(`a`, int(b.size_val))

	b.encoded = b64.encode(str.bytes())
	b.decoded = b64.decode(b.encoded)
	b.result_val = 0
}
