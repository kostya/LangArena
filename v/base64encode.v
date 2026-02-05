module base64encode

import benchmark
import helper
import encoding.base64 as b64

pub struct Base64Encode {
	benchmark.BaseBenchmark
	size_val i64
mut:
	str        string
	encoded    string
	result_val u32
}

pub fn new_base64encode() &benchmark.IBenchmark {
	size_val := helper.config_i64('Base64Encode', 'size')

	mut bench := &Base64Encode{
		BaseBenchmark: benchmark.new_base_benchmark('Base64Encode')
		size_val:      size_val
		str:           ''
		encoded:       ''
		result_val:    0
	}

	return bench
}

pub fn (b Base64Encode) name() string {
	return 'Base64Encode'
}

fn (mut b Base64Encode) prepare_for_checksum() {

	mut str := ''
	for _ in 0 .. b.size_val {
		str += 'a'
	}
	b.str = str

	b.encoded = b64.encode(b.str.bytes())
}

pub fn (mut b Base64Encode) run(iteration_id int) {
	_ = iteration_id

	encoded := b64.encode(b.str.bytes())

	b.result_val += u32(encoded.len)
}

pub fn (b Base64Encode) checksum() u32 {

	mut desc := 'encode '

	if b.str.len > 4 {
		desc += b.str[..4] + '...'
	} else {
		desc += b.str
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
	b.prepare_for_checksum()
	b.result_val = 0
}