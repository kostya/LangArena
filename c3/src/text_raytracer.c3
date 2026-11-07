module text_raytracer;

import benchmark;
import helper;
import std::io;
import std::math;

struct TRVector
{
	double x, y, z;
}

struct TRRay
{
	TRVector orig;
	TRVector dir;
}

struct TRColor
{
	double r, g, b;
}

struct TRSphere
{
	TRVector center;
	double radius;
	TRColor color;
}

struct TRLight
{
	TRVector position;
	TRColor color;
}

struct TextRaytracerData
{
	int width;
	int height;
	uint result_val;
}

fn TRVector tr_vector_scale(TRVector v, double s)
{
	return { v.x * s, v.y * s, v.z * s };
}

fn TRVector tr_vector_add(TRVector a, TRVector b)
{
	return { a.x + b.x, a.y + b.y, a.z + b.z };
}

fn TRVector tr_vector_sub(TRVector a, TRVector b)
{
	return { a.x - b.x, a.y - b.y, a.z - b.z };
}

fn double tr_vector_dot(TRVector a, TRVector b)
{
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

fn double tr_vector_magnitude(TRVector v)
{
	return math::sqrt(tr_vector_dot(v, v));
}

fn TRVector tr_vector_normalize(TRVector v)
{
	double mag = tr_vector_magnitude(v);
	if (mag == 0.0) return { 0, 0, 0 };
	return tr_vector_scale(v, 1.0 / mag);
}

fn TRColor tr_color_scale(TRColor c, double s)
{
	return { c.r * s, c.g * s, c.b * s };
}

fn TRColor tr_color_add(TRColor a, TRColor b)
{
	return { a.r + b.r, a.g + b.g, a.b + b.b };
}

fn TRVector tr_sphere_get_normal(TRSphere* sphere, TRVector pt)
{
	return tr_vector_normalize(tr_vector_sub(pt, sphere.center));
}

fn double tr_clamp(double x, double a, double b)
{
	if (x < a) return a;
	if (x > b) return b;
	return x;
}

fn double tr_intersect_sphere(TRRay ray, TRVector center, double radius)
{
	TRVector l = tr_vector_sub(center, ray.orig);
	double tca = tr_vector_dot(l, ray.dir);
	if (tca < 0.0) return -1.0;

	double d2 = tr_vector_dot(l, l) - tca * tca;
	double r2 = radius * radius;
	if (d2 > r2) return -1.0;

	double thc = math::sqrt(r2 - d2);
	double t0  = tca - thc;
	if (t0 > 10000.0) return -1.0;

	return t0;
}

fn TRColor tr_diffuse_shading(TRVector pi, TRSphere* obj, TRLight light)
{
	TRVector n         = tr_sphere_get_normal(obj, pi);
	TRVector light_dir = tr_vector_normalize(tr_vector_sub(light.position, pi));
	double lam1        = tr_vector_dot(light_dir, n);
	double lam2        = tr_clamp(lam1, 0.0, 1.0);

	TRColor light_color = tr_color_scale(light.color, lam2 * 0.5);
	TRColor obj_color   = tr_color_scale(obj.color, 0.3);
	return tr_color_add(light_color, obj_color);
}

const char[6] LUT = { '.', '-', '+', '*', 'X', 'M' };

fn void text_raytracer_prepare(Benchmark* self)
{
	TextRaytracerData* data = (TextRaytracerData*)self.data;

	data.width = (int)helper::helper_config_i64(self.name, "w");
	data.height = (int)helper::helper_config_i64(self.name, "h");

	if (data.width <= 0)
	{
		data.width = 10;
	}
	if (data.height <= 0)
	{
		data.height = 10;
	}
}

fn void text_raytracer_run(Benchmark* self, int iteration_id)
{
	TextRaytracerData* data = (TextRaytracerData*)self.data;

	TRSphere[3] scene = {
		{ { -1.0, 0.0, 3.0 }, 0.3, { 1.0, 0.0, 0.0 } },
		{ { 0.0, 0.0, 3.0 }, 0.8, { 0.0, 1.0, 0.0 } },
		{ { 1.0, 0.0, 3.0 }, 0.4, { 0.0, 0.0, 1.0 } }
	};

	TRLight light1 = { { 0.7, -1.0, 1.7 }, { 1.0, 1.0, 1.0 } };

	uint iteration_result = 0;

	for (int j = 0; j < data.height; j++)
	{
		for (int i = 0; i < data.width; i++)
		{
			double fw = (double)data.width;
			double fh = (double)data.height;
			double fi = (double)i;
			double fj = (double)j;

			TRRay ray;
			ray.orig = { 0.0, 0.0, 0.0 };

			TRVector dir = { (fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0 };
			ray.dir = tr_vector_normalize(dir);

			double tval       = -1.0;
			TRSphere* hit_obj =  null;

			for (int k = 0; k < 3; k++)
			{
				double intersect = tr_intersect_sphere(ray, scene[k].center, scene[k].radius);
				if (intersect >= 0.0)
				{
					tval = intersect;
					hit_obj = &scene[k];
					break;
				}
			}

			char pixel = ' ';
			if (hit_obj && tval >= 0.0)
			{
				TRVector pi   = tr_vector_add(ray.orig, tr_vector_scale(ray.dir, tval));
				TRColor color = tr_diffuse_shading(pi, hit_obj, light1);
				double col    = (color.r + color.g + color.b) / 3.0;
				int idx       = (int)(col * 6.0);
				if (idx < 0)
				{
					idx = 0;
				}
				if (idx >= 6)
				{
					idx = 5;
				}
				pixel = LUT[idx];
			}

			iteration_result += (uint)pixel;
		}
	}

	data.result_val += iteration_result;
}

fn uint text_raytracer_checksum(Benchmark* self)
{
	return ((TextRaytracerData*)self.data).result_val;
}

fn void text_raytracer_cleanup(Benchmark* self)
{
}

fn Benchmark* text_raytracer_create() @cname("TextRaytracer_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::TextRaytracer");

	TextRaytracerData* data = mem::new(TextRaytracerData);

	bench.data = data;
	bench.prepare = (PrepareFn)&text_raytracer_prepare;
	bench.run = (RunFn)&text_raytracer_run;
	bench.checksum = (ChecksumFn)&text_raytracer_checksum;
	bench.cleanup = (CleanupFn)&text_raytracer_cleanup;

	return bench;
}