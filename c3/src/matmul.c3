module matmul;

import benchmark;
import helper;
import std::io;
import std::thread;

fn double** matgen(int n)
{
	double tmp = 1.0 / (double)n / (double)n;
	double** a = mem::alloc_array(double*, (usz)n);

	for (int i = 0; i < n; i++)
	{
		a[i] = mem::new_array(double, (usz)n);
		for (int j = 0; j < n; j++)
		{
			a[i][j] = tmp * (double)(i - j) * (double)(i + j);
		}
	}
	return a;
}

fn void free_matrix(double** a, int n)
{
	if (!a) return;
	for (int i = 0; i < n; i++)
	{
		free(a[i]);
	}
	free(a);
}

fn double** transpose(double** b, int n)
{
	double** b_t = mem::alloc_array(double*, (usz)n);
	for (int j = 0; j < n; j++)
	{
		b_t[j] = mem::new_array(double, (usz)n);
		for (int i = 0; i < n; i++)
		{
			b_t[j][i] = b[i][j];
		}
	}
	return b_t;
}

struct MatmulBaseData
{
	long n;
	uint result_val;
	double** a;
	double** b;
}

fn uint matmul_checksum(Benchmark* self)
{
	MatmulBaseData* data = (MatmulBaseData*)self.data;
	return data.result_val;
}

fn void matmul_base_prepare(Benchmark* self)
{
	MatmulBaseData* data = (MatmulBaseData*)self.data;
	int n                = (int)data.n;

	data.a = matgen(n);
	data.b = matgen(n);
}

fn void matmul_base_cleanup(Benchmark* self)
{
	MatmulBaseData* data = (MatmulBaseData*)self.data;
	int n                = (int)data.n;

	free_matrix(data.a, n);
	data.a = null;
	free_matrix(data.b, n);
	data.b = null;
}

fn double** matmul_sequential(double** a, double** b, int n)
{
	double** b_t = transpose(b, n);
	double** c   = mem::alloc_array(double*, (usz)n);

	for (int i = 0; i < n; i++)
	{
		c[i] = mem::new_array(double, (usz)n);
		double* ai = a[i];
		for (int j = 0; j < n; j++)
		{
			double s     = 0.0;
			double* b_tj = b_t[j];

			for (int k = 0; k < n; k++)
			{
				s += ai[k] * b_tj[k];
			}
			c[i][j] = s;
		}
	}

	free_matrix(b_t, n);
	return c;
}

fn void matmul_run(Benchmark* self, int iteration_id)
{
	MatmulBaseData* data = (MatmulBaseData*)self.data;
	int n                = (int)data.n;

	double** c          = matmul_sequential(data.a, data.b, n);
	double center_value = c[n >> 1][n >> 1];
	free_matrix(c, n);

	uint iter_checksum = helper::helper_checksum_f64(center_value);
	data.result_val += iter_checksum;
}

fn Benchmark* matmul_create() @cname("Matmul_create") @export
{
	Benchmark* bench     = benchmark::benchmark_create("Matmul::Single");
	MatmulBaseData* data = mem::new(MatmulBaseData);

	data.n = helper::helper_config_i64("Matmul::Single", "n");

	bench.data = data;
	bench.prepare = (PrepareFn)&matmul_base_prepare;
	bench.run = (RunFn)&matmul_run;
	bench.checksum = (ChecksumFn)&matmul_checksum;
	bench.cleanup = (CleanupFn)&matmul_base_cleanup;

	return bench;
}

struct MatmulParallelData
{
	MatmulBaseData base;
	int num_threads;
}

struct MatmulThreadData
{
	double** a;
	double** b_t;
	double** c;
	int n;
	int start_row;
	int end_row;
}

fn int thread_func(void* arg)
{
	MatmulThreadData* data = (MatmulThreadData*)arg;

	for (int i = data.start_row; i < data.end_row; i++)
	{
		double* ai = data.a[i];
		double* ci = data.c[i];

		for (int j = 0; j < data.n; j++)
		{
			double sum   = 0.0;
			double* b_tj = data.b_t[j];

			for (int k = 0; k < data.n; k++)
			{
				sum += ai[k] * b_tj[k];
			}
			ci[j] = sum;
		}
	}

	return 0;
}

fn double** matmul_parallel(double** a, double** b, int n, int num_threads)
{
	double** b_t = transpose(b, n);
	double** c   = mem::alloc_array(double*, (usz)n);
	for (int i = 0; i < n; i++)
	{
		c[i] = mem::new_array(double, (usz)n);
	}

	int rows_per_thread           = (n + num_threads - 1) / num_threads;
	MatmulThreadData* thread_data = mem::alloc_array(MatmulThreadData, (usz)num_threads);
	Thread* threads               = mem::new_array(Thread, (usz)num_threads);

	for (int t = 0; t < num_threads; t++)
	{
		thread_data[t].a = a;
		thread_data[t].b_t = b_t;
		thread_data[t].c = c;
		thread_data[t].n = n;
		thread_data[t].start_row = t * rows_per_thread;
		thread_data[t].end_row = thread_data[t].start_row + rows_per_thread;
		if (thread_data[t].end_row > n || t == num_threads - 1)
		{
			thread_data[t].end_row = n;
		}

		(void)Thread.create(&threads[t], &thread_func, &thread_data[t]);
	}

	for (int t = 0; t < num_threads; t++)
	{
		(void)Thread.join(threads[t]);
	}

	free(threads);
	free(thread_data);
	free_matrix(b_t, n);
	return c;
}

fn void matmul_parallel_run(Benchmark* self, int iteration_id)
{
	MatmulParallelData* data = (MatmulParallelData*)self.data;
	int n                    = (int)data.base.n;

	double** c          = matmul_parallel(data.base.a, data.base.b, n, data.num_threads);
	double center_value = c[n >> 1][n >> 1];
	free_matrix(c, n);

	uint iter_checksum = helper::helper_checksum_f64(center_value);
	data.base.result_val += iter_checksum;
}

fn Benchmark* matmul4t_create() @cname("Matmul4T_create") @export
{
	Benchmark* bench         = benchmark::benchmark_create("Matmul::T4");
	MatmulParallelData* data = mem::new(MatmulParallelData);

	data.base.n = helper::helper_config_i64("Matmul::T4", "n");
	data.num_threads = 4;

	bench.data = data;
	bench.prepare = (PrepareFn)&matmul_base_prepare;
	bench.run = (RunFn)&matmul_parallel_run;
	bench.checksum = (ChecksumFn)&matmul_checksum;
	bench.cleanup = (CleanupFn)&matmul_base_cleanup;

	return bench;
}

fn Benchmark* matmul8t_create() @cname("Matmul8T_create") @export
{
	Benchmark* bench         = benchmark::benchmark_create("Matmul::T8");
	MatmulParallelData* data = mem::new(MatmulParallelData);

	data.base.n = helper::helper_config_i64("Matmul::T8", "n");
	data.num_threads = 8;

	bench.data = data;
	bench.prepare = (PrepareFn)&matmul_base_prepare;
	bench.run = (RunFn)&matmul_parallel_run;
	bench.checksum = (ChecksumFn)&matmul_checksum;
	bench.cleanup = (CleanupFn)&matmul_base_cleanup;

	return bench;
}

fn Benchmark* matmul16t_create() @cname("Matmul16T_create") @export
{
	Benchmark* bench         = benchmark::benchmark_create("Matmul::T16");
	MatmulParallelData* data = mem::new(MatmulParallelData);

	data.base.n = helper::helper_config_i64("Matmul::T16", "n");
	data.num_threads = 16;

	bench.data = data;
	bench.prepare = (PrepareFn)&matmul_base_prepare;
	bench.run = (RunFn)&matmul_parallel_run;
	bench.checksum = (ChecksumFn)&matmul_checksum;
	bench.cleanup = (CleanupFn)&matmul_base_cleanup;

	return bench;
}