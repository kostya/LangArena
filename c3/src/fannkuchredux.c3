module fannkuchredux;

import benchmark;
import helper;
import std::io;

struct FannkuchreduxData
{
	long n;
	uint result_val;
}

fn void fannkuchredux_swap(int* a, int* b)
{
	int temp = *a;
	*a = *b;
	*b = temp;
}

fn void fannkuchredux_calculate(int n, int* checksum, int* max_flips)
{
	int[32] perm1;
	int[32] perm;
	int[32] count;

	if (n > 32) n = 32;

	for (int i = 0; i < n; i++)
	{
		perm1[i] = i;
	}

	*max_flips = 0;
	*checksum = 0;
	int permCount = 0;
	int r         = n;

	while (true)
	{
		while (r > 1)
		{
			count[r - 1] = r;
			r--;
		}

		for (int i = 0; i < n; i++)
		{
			perm[i] = perm1[i];
		}

		int flipsCount = 0;
		int k          = perm[0];

		while (k != 0)
		{
			int k2 = (k + 1) >> 1;
			for (int i = 0; i < k2; i++)
			{
				int j = k - i;
				fannkuchredux_swap(&perm[i], &perm[j]);
			}
			flipsCount++;
			k = perm[0];
		}

		if (flipsCount > *max_flips)
		{
			*max_flips = flipsCount;
		}
		*checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;

		while (true)
		{
			if (r == n) return;

			int perm0 = perm1[0];
			for (int i = 0; i < r; i++)
			{
				perm1[i] = perm1[i + 1];
			}
			perm1[r] = perm0;

			count[r]--;
			if (count[r] > 0) break;
			r++;
		}
		permCount++;
	}
}

fn void fannkuchredux_prepare(Benchmark* self)
{
	FannkuchreduxData* data = (FannkuchreduxData*)self.data;
	data.n = helper::helper_config_i64(self.name, "n");
	if (data.n == 0)
	{
		data.n = 12;
	}
}

fn void fannkuchredux_run(Benchmark* self, int iteration_id)
{
	FannkuchreduxData* data = (FannkuchreduxData*)self.data;

	int checksum;
	int max_flips;
	fannkuchredux_calculate((int)data.n, &checksum, &max_flips);

	data.result_val += (uint)((long)checksum * 100 + max_flips);
}

fn uint fannkuchredux_checksum(Benchmark* self)
{
	FannkuchreduxData* data = (FannkuchreduxData*)self.data;
	return data.result_val;
}

fn void fannkuchredux_cleanup(Benchmark* self)
{
}

fn Benchmark* fannkuchredux_create() @cname("Fannkuchredux_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("CLBG::Fannkuchredux");

	FannkuchreduxData* data = mem::new(FannkuchreduxData);

	bench.data = data;
	bench.prepare = (PrepareFn)&fannkuchredux_prepare;
	bench.run = (RunFn)&fannkuchredux_run;
	bench.checksum = (ChecksumFn)&fannkuchredux_checksum;
	bench.cleanup = (CleanupFn)&fannkuchredux_cleanup;

	return bench;
}