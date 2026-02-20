module benchmark

import helper

pub struct BaseBenchmark {
pub mut:
	class_name string
}

pub fn new_base_benchmark(class_name string) BaseBenchmark {
	return BaseBenchmark{
		class_name: class_name
	}
}

pub fn (mut b BaseBenchmark) prepare() {
}

pub fn (mut b BaseBenchmark) run(iteration_id int) {
}

pub fn (mut b BaseBenchmark) warmup(mut bench IBenchmark) {
	prepare_iters := b.warmup_iterations()
	for i in 0 .. prepare_iters {
		bench.run(int(i))
	}
}

pub fn (b BaseBenchmark) warmup_iterations() i64 {
	warmup := helper.config_i64(b.class_name, 'warmup_iterations')
	if warmup > 0 {
		return warmup
	}

	iters := b.iterations()
	warmup_default := i64(f64(iters) * 0.2)
	return if warmup_default < 1 { 1 } else { warmup_default }
}

pub fn (b BaseBenchmark) iterations() i64 {
	iters := helper.config_i64(b.class_name, 'iterations')
	return if iters > 0 { iters } else { 1 }
}

pub fn (b BaseBenchmark) expected_checksum() i64 {
	return helper.config_i64(b.class_name, 'checksum')
}

pub fn (b &BaseBenchmark) config_i64(field_name string) i64 {
	return helper.config_i64(b.class_name, field_name)
}

pub fn (b &BaseBenchmark) config_string(field_name string) string {
	return ''
}
