module benchmark;

import helper;
import std::io;
import std::thread;
import std::time;
import std::os;

alias PrepareFn = fn void(void* self);
alias RunFn = fn void(void* self, int iteration_id);
alias RunAllFn = fn void(void* self);
alias WarmupFn = fn void(void* self);
alias ChecksumFn = fn uint(void* self);
alias IterationsFn = fn long(void* self);
alias CleanupFn = fn void(void* self);

struct Benchmark
{
	String name;
	uint checksum_val;
	long iterations_val;

	PrepareFn prepare;
	RunFn run;
	RunAllFn run_all;
	WarmupFn warmup;
	ChecksumFn checksum;
	IterationsFn iterations;
	IterationsFn expected_checksum;
	CleanupFn cleanup;

	void* data;
}

fn void benchmark_default_prepare(Benchmark* self)
{
}

fn void benchmark_default_warmup(Benchmark* self)
{
	long warmup_iters = helper::helper_config_i64(self.name, "warmup_iterations");
	if (warmup_iters == 0)
	{
		warmup_iters = self.iterations(self);
		warmup_iters = (long)(warmup_iters * 0.2);
		if (warmup_iters < 1) warmup_iters = 1;
	}

	for (long i = 0; i < warmup_iters; i++)
	{
		self.run(self, (int)i);
	}
}

fn void benchmark_default_run_all(Benchmark* self)
{
	long iters = self.iterations(self);
	for (long i = 0; i < iters; i++)
	{
		self.run(self, (int)i);
	}
}

fn uint benchmark_default_checksum(Benchmark* self)
{
	return self.checksum_val;
}

fn long benchmark_default_iterations(Benchmark* self)
{
	if (self.iterations_val > 0) return self.iterations_val;
	self.iterations_val = helper::helper_config_i64(self.name, "iterations");
	return self.iterations_val;
}

fn long benchmark_default_expected_checksum(Benchmark* self)
{
	return helper::helper_config_i64(self.name, "checksum");
}

fn void benchmark_default_cleanup(Benchmark* self)
{
}

fn Benchmark* benchmark_create(String name)
{
	Benchmark* bench = mem::new(Benchmark);
	bench.name = name;

	bench.prepare = (PrepareFn)&benchmark_default_prepare;
	bench.warmup = (WarmupFn)&benchmark_default_warmup;
	bench.run_all = (RunAllFn)&benchmark_default_run_all;
	bench.checksum = (ChecksumFn)&benchmark_default_checksum;
	bench.iterations = (IterationsFn)&benchmark_default_iterations;
	bench.expected_checksum = (IterationsFn)&benchmark_default_expected_checksum;
	bench.cleanup = (CleanupFn)&benchmark_default_cleanup;

	return bench;
}

alias FactoryFn = fn Benchmark*();

struct BenchmarkFactory
{
	char[100] name;
	FactoryFn create;
}

BenchmarkFactory* benchmark_factories;
usz benchmark_factories_count;
usz benchmark_factories_capacity;

fn void benchmark_register(String name, FactoryFn factory_func)
{
	if (benchmark_factories_count >= benchmark_factories_capacity)
	{
		benchmark_factories_capacity = benchmark_factories_capacity ? benchmark_factories_capacity * 2 : 16;
		benchmark_factories = mem::realloc(
			benchmark_factories,
			(sz)benchmark_factories_capacity * BenchmarkFactory::size
		);
	}

	sz len = name.len;
	if (len > 99) len = 99;
	benchmark_factories[benchmark_factories_count].name[:len] = name[:len];
	benchmark_factories[benchmark_factories_count].name[len] = 0;

	benchmark_factories[benchmark_factories_count].create = factory_func;
	benchmark_factories_count++;
}

fn void benchmark_run_all(String single_bench)
{
	double summary_time = 0.0;
	int ok              = 0;
	int fails           = 0;

	foreach (bench_name : helper::global_order)
	{
		if (single_bench.len > 0)
		{
			@pool()
			{
				String bench_lower  = bench_name.to_lower_tcopy();
				String filter_lower = single_bench.to_lower_tcopy();
				if (!bench_lower.contains(filter_lower)) continue;
			};
		}

		FactoryFn found_factory = null;
		for (usz j = 0; j < benchmark_factories_count; j++)
		{
			if (((ZString)&benchmark_factories[j].name).str_view() == bench_name)
			{
				found_factory = benchmark_factories[j].create;
				break;
			}
		}

		if (!found_factory)
		{
			io::printfn("Warning: Benchmark '%s' not found", bench_name);
			continue;
		}

		io::printf("%s: ", bench_name);

		Benchmark* bench = found_factory();

		helper::helper_reset();
		bench.prepare(bench);

		bench.warmup(bench);

		helper::helper_reset();

		Clock start = clock::now();

		bench.run_all(bench);

		Clock end         = clock::now();
		NanoDuration diff = end - start;
		double duration   = diff.to_sec();

		summary_time += duration;

		uint actual_checksum = bench.checksum(bench);
		uint expected        = (uint)bench.expected_checksum(bench);

		if (actual_checksum == expected)
		{
			io::printfn("OK in %.3fs", duration);
			ok++;
		}
		else
		{
			io::printfn("ERR[actual=%d, expected=%d] in %.3fs", actual_checksum, expected, duration);
			fails++;
		}

		bench.cleanup(bench);
		free(bench.data);
		free(bench);

		(void)thread::sleep_ms(1);
	}

	if (ok + fails > 0)
	{
		io::printfn("Summary: %.4fs, %d, %d, %d", summary_time, ok + fails, ok, fails);
	}

	if (fails > 0)
	{
		os::exit(1);
	}
}