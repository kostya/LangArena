module sieve;

import benchmark;
import helper;
import std::io;
import std::math;

struct SieveData
{
	long limit;
	uint checksum;
}

fn int sieve_generate(long limit)
{
	if (limit < 2) return 0;

	char[] primes = mem::new_array(char, (usz)(limit + 1));
	primes[..] = 1;
	primes[0] = 0;
	primes[1] = 0;

	int sqrt_limit = (int)math::sqrt((double)limit);

	for (int p = 2; p <= sqrt_limit; p++)
	{
		if (primes[p] == 1)
		{
			for (long multiple = (long)p * p; multiple <= limit; multiple += p)
			{
				primes[multiple] = 0;
			}
		}
	}

	int last_prime   = 2;
	int count_primes = 1;

	for (long n = 3; n <= limit; n += 2)
	{
		if (primes[n] == 1)
		{
			last_prime = (int)n;
			count_primes++;
		}
	}

	free(primes);
	return last_prime + count_primes;
}

fn void sieve_prepare(Benchmark* self)
{
	SieveData* data = (SieveData*)self.data;
	data.limit = helper::helper_config_i64(self.name, "limit");
	if (data.limit <= 0)
	{
		data.limit = 1000000;
	}
}

fn void sieve_run(Benchmark* self, int iteration_id)
{
	SieveData* data = (SieveData*)self.data;
	int sum         = sieve_generate(data.limit);
	data.checksum += (uint)sum;
}

fn uint sieve_checksum(Benchmark* self)
{
	return ((SieveData*)self.data).checksum;
}

fn void sieve_cleanup(Benchmark* self)
{
	SieveData* data = (SieveData*)self.data;
	if (data)
	{
		free(data);
		self.data = null;
	}
}

fn Benchmark* sieve_create() @cname("Sieve_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::Sieve");

	SieveData* data = mem::new(SieveData);

	bench.data = data;
	bench.prepare = (PrepareFn)&sieve_prepare;
	bench.run = (RunFn)&sieve_run;
	bench.checksum = (ChecksumFn)&sieve_checksum;
	bench.cleanup = (CleanupFn)&sieve_cleanup;

	return bench;
}