module spectralnorm;

import benchmark;
import helper;
import std::io;
import std::math;

struct SpectralnormData
{
	long size_val;
	double* u;
	double* v;
}

fn void spectralnorm_prepare(Benchmark* self)
{
	SpectralnormData* data = (SpectralnormData*)self.data;
	data.size_val = helper::helper_config_i64(self.name, "size");
	if (data.size_val <= 0)
	{
		data.size_val = 100;
	}

	data.u = mem::new_array(double, (usz)data.size_val);
	data.v = mem::new_array(double, (usz)data.size_val);

	for (long i = 0; i < data.size_val; i++)
	{
		data.u[i] = 1.0;
		data.v[i] = 1.0;
	}
}

fn double eval_A(long i, long j)
{
	return 1.0 / ((double)(i + j) * (double)(i + j + 1) / 2.0 + (double)i + 1.0);
}

fn double* eval_A_times_u(double* u, long n)
{
	double* result = mem::new_array(double, (usz)n);
	for (long i = 0; i < n; i++)
	{
		double sum = 0.0;
		for (long j = 0; j < n; j++)
		{
			sum += eval_A(i, j) * u[j];
		}
		result[i] = sum;
	}
	return result;
}

fn double* eval_At_times_u(double* u, long n)
{
	double* result = mem::new_array(double, (usz)n);
	for (long i = 0; i < n; i++)
	{
		double sum = 0.0;
		for (long j = 0; j < n; j++)
		{
			sum += eval_A(j, i) * u[j];
		}
		result[i] = sum;
	}
	return result;
}

fn double* eval_AtA_times_u(double* u, long n)
{
	double* temp   = eval_A_times_u(u, n);
	double* result = eval_At_times_u(temp, n);
	free(temp);
	return result;
}

fn void spectralnorm_run(Benchmark* self, int iteration_id)
{
	SpectralnormData* data = (SpectralnormData*)self.data;

	double* new_v = eval_AtA_times_u(data.u, data.size_val);
	double* new_u = eval_AtA_times_u(new_v, data.size_val);

	free(data.u);
	free(data.v);

	data.u = new_u;
	data.v = new_v;
}

fn uint spectralnorm_checksum(Benchmark* self)
{
	SpectralnormData* data = (SpectralnormData*)self.data;

	double vBv = 0.0;
	double vv  = 0.0;
	for (long i = 0; i < data.size_val; i++)
	{
		vBv += data.u[i] * data.v[i];
		vv += data.v[i] * data.v[i];
	}

	double result = math::sqrt(vBv / vv);
	return helper::helper_checksum_f64(result);
}

fn void spectralnorm_cleanup(Benchmark* self)
{
	SpectralnormData* data = (SpectralnormData*)self.data;
	free(data.u);
	free(data.v);
}

fn Benchmark* spectralnorm_create() @cname("Spectralnorm_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("CLBG::Spectralnorm");

	SpectralnormData* data = mem::new(SpectralnormData);

	bench.data = data;
	bench.prepare = (PrepareFn)&spectralnorm_prepare;
	bench.run = (RunFn)&spectralnorm_run;
	bench.checksum = (ChecksumFn)&spectralnorm_checksum;
	bench.cleanup = (CleanupFn)&spectralnorm_cleanup;

	return bench;
}