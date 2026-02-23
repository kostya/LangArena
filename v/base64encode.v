module base64encode

import benchmark
import helper
import encoding.base64 as b64
import strings

pub struct Base64Encode {
	benchmark.BaseBenchmark
	size_val i64
mut:
	str        []byte
	encoded    string
	result_val u32
}

pub fn new_base64encode() &benchmark.IBenchmark {
	size_val := helper.config_i64('Base64::Encode', 'size')

	mut bench := &Base64Encode{
		BaseBenchmark: benchmark.new_base_benchmark('Base64::Encode')
		size_val:      size_val
		str:           []
		encoded:       ''
		result_val:    0
	}

	return bench
}

pub fn (b Base64Encode) name() string {
	return 'Base64::Encode'
}

pub fn (mut b Base64Encode) run(iteration_id int) {
	encoded := b64.encode(b.str)
	b.result_val += u32(encoded.len)
}

pub fn (b Base64Encode) checksum() u32 {
	mut desc := 'encode '

	str := b.str[0..5].bytestr()

	if str.len > 4 {
		desc += str[..4] + '...'
	} else {
		desc += str
	}

	desc += ' to '

	if b.encoded.len > 4 {
		desc += b.encoded[..4] + '...'
	} else {
		desc += b.encoded
	}

	desc += ': ${b.result_val}'

	return helper.checksum_str(desc)
}

pub fn (mut b Base64Encode) prepare() {
	mut str := strings.repeat(`a`, int(b.size_val))
	b.str = str.bytes()
	b.encoded = b64.encode(b.str)
	b.result_val = 0
}
