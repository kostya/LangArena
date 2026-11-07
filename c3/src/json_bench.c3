module json_bench;

import benchmark;
import helper;
import std::io;
import std::encoding::json;
import std::collections::object;
import std::math;

struct Coordinate
{
	double x, y, z;
	String name;
	Object* opts;
}

struct JsonGenerateContainer
{
	Coordinate[] coordinates;
	String info;
}

struct CoordinateData
{
	double x, y, z;
}

struct CoordinatesData
{
	CoordinateData[] coordinates;
}

struct JsonGenerateData
{
	Coordinate[] coords;
	long n;
	DString result_str;
	uint result_val;
}

fn double round_to_8_digits(double value)
{
	return math::round(value * 1e8) / 1e8;
}

fn void json_generate_prepare(Benchmark* self)
{
	JsonGenerateData* data = (JsonGenerateData*)self.data;

	data.result_str.clear();
	data.result_val = 0;

	data.coords = mem::new_array(Coordinate, (usz)data.n);

	for (long i = 0; i < data.n; i++)
	{
		data.coords[i].x = round_to_8_digits(helper::helper_next_float(1.0));
		data.coords[i].y = round_to_8_digits(helper::helper_next_float(1.0));
		data.coords[i].z = round_to_8_digits(helper::helper_next_float(1.0));

		String name = string::tformat("%.7f %d", helper::helper_next_float(1.0), helper::helper_next_int(10000));
		data.coords[i].name = name.copy(mem);
		data.coords[i].opts = object::new_obj(mem);
		Object* arr = object::new_array(mem);
		arr.push(1);
		arr.push(true);
		data.coords[i].opts.set("1", arr);
	}
}

fn void json_generate_run(Benchmark* self, int iteration_id)
{
	JsonGenerateData* data = (JsonGenerateData*)self.data;

	data.result_str.free();
	data.result_str.init(mem, 4096);

	JsonGenerateContainer container = {
		.coordinates = data.coords,
		.info = "some info",
	};

	json::marshal_to(&data.result_str, container)!!;

	if (data.result_str.str_view().starts_with("{"))
	{
		data.result_val++;
	}
}

fn uint json_generate_checksum(Benchmark* self)
{
	return ((JsonGenerateData*)self.data).result_val;
}

fn void json_generate_cleanup(Benchmark* self)
{
	JsonGenerateData* data = (JsonGenerateData*)self.data;
	if (data.coords)
	{
		for (long i = 0; i < data.n; i++)
		{
			free(data.coords[i].name);
			data.coords[i].opts.free();
		}
		free(data.coords);
	}
	data.result_str.free();
}

fn Benchmark* json_generate_create() @cname("JsonGenerate_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Json::Generate");

	JsonGenerateData* data = mem::new(JsonGenerateData);
	data.n = helper::helper_config_i64(bench.name, "coords");

	bench.data = data;
	bench.prepare = (PrepareFn)&json_generate_prepare;
	bench.run = (RunFn)&json_generate_run;
	bench.checksum = (ChecksumFn)&json_generate_checksum;
	bench.cleanup = (CleanupFn)&json_generate_cleanup;

	return bench;
}

fn String generate_json_for_parsing(long coords_count)
{
	Benchmark* gen_bench       = json_generate_create();
	JsonGenerateData* gen_data = (JsonGenerateData*)gen_bench.data;
	gen_data.n = coords_count;
	json_generate_prepare(gen_bench);
	json_generate_run(gen_bench, 0);

	String result = gen_data.result_str.copy_str(mem);

	json_generate_cleanup(gen_bench);
	free(gen_bench.data);
	free(gen_bench);

	return result;
}

struct JsonParseDomData
{
	String json_text;
	uint result_val;
	long coords_count;
}

fn void json_parse_dom_prepare(Benchmark* self)
{
	JsonParseDomData* data = (JsonParseDomData*)self.data;
	data.coords_count = helper::helper_config_i64(self.name, "coords");
	data.json_text = generate_json_for_parsing(data.coords_count);
}

fn void json_parse_dom_run(Benchmark* self, int iteration_id)
{
	JsonParseDomData* data = (JsonParseDomData*)self.data;

	Object*? doc_opt = json::parse(mem, data.json_text);
	if (catch err = doc_opt) return;

	Object* doc = doc_opt;
	defer doc.free();

	Object*? coords_opt = doc.get("coordinates");
	if (catch coords_opt) return;
	if (!coords_opt.is_array()) return;

	double x_sum = 0.0;
	double y_sum = 0.0;
	double z_sum = 0.0;
	usz len      = 0;

	sz count = coords_opt.get_len();
	for (sz i = 0; i < count; i++)
	{
		Object* coord = coords_opt.get_at(i);
		if (!coord.is_map()) continue;

		if (try x_val = coord.get_float("x"))
		{
			if (try y_val = coord.get_float("y"))
			{
				if (try z_val = coord.get_float("z"))
				{
					x_sum += x_val;
					y_sum += y_val;
					z_sum += z_val;
					len++;
				}
			}
		}
	}

	if (len > 0)
	{
		double x_avg = x_sum / (double)len;
		double y_avg = y_sum / (double)len;
		double z_avg = z_sum / (double)len;

		uint checksum = helper::helper_checksum_f64(
			x_avg
		) + helper::helper_checksum_f64(y_avg) + helper::helper_checksum_f64(z_avg);
		data.result_val += checksum;
	}
}

fn uint json_parse_dom_checksum(Benchmark* self)
{
	return ((JsonParseDomData*)self.data).result_val;
}

fn void json_parse_dom_cleanup(Benchmark* self)
{
	JsonParseDomData* data = (JsonParseDomData*)self.data;
	free(data.json_text);
	data.json_text = "";
}

fn Benchmark* json_parse_dom_create() @cname("JsonParseDom_create") @export
{
	Benchmark* bench       = benchmark::benchmark_create("Json::ParseDom");
	JsonParseDomData* data = mem::new(JsonParseDomData);

	bench.data = data;
	bench.prepare = (PrepareFn)&json_parse_dom_prepare;
	bench.run = (RunFn)&json_parse_dom_run;
	bench.checksum = (ChecksumFn)&json_parse_dom_checksum;
	bench.cleanup = (CleanupFn)&json_parse_dom_cleanup;

	return bench;
}

struct JsonParseMappingData
{
	String json_text;
	uint result_val;
	long coords_count;
}

fn void json_parse_mapping_prepare(Benchmark* self)
{
	JsonParseMappingData* data = (JsonParseMappingData*)self.data;
	data.coords_count = helper::helper_config_i64(self.name, "coords");
	data.json_text = generate_json_for_parsing(data.coords_count);
}

fn void json_parse_mapping_run(Benchmark* self, int iteration_id)
{
	JsonParseMappingData* data = (JsonParseMappingData*)self.data;

	CoordinatesData coords_data = json::unmarshal(tmem, data.json_text, CoordinatesData)!!;

	double x_sum = 0.0;
	double y_sum = 0.0;
	double z_sum = 0.0;
	usz len      = coords_data.coordinates.len;

	foreach (coord : coords_data.coordinates)
	{
		x_sum += coord.x;
		y_sum += coord.y;
		z_sum += coord.z;
	}

	if (len > 0)
	{
		double x_avg = x_sum / (double)len;
		double y_avg = y_sum / (double)len;
		double z_avg = z_sum / (double)len;

		uint checksum = helper::helper_checksum_f64(
			x_avg
		) + helper::helper_checksum_f64(y_avg) + helper::helper_checksum_f64(z_avg);
		data.result_val += checksum;
	}
}

fn uint json_parse_mapping_checksum(Benchmark* self)
{
	return ((JsonParseMappingData*)self.data).result_val;
}

fn void json_parse_mapping_cleanup(Benchmark* self)
{
	JsonParseMappingData* data = (JsonParseMappingData*)self.data;
	free(data.json_text);
	data.json_text = "";
}

fn Benchmark* json_parse_mapping_create() @cname("JsonParseMapping_create") @export
{
	Benchmark* bench           = benchmark::benchmark_create("Json::ParseMapping");
	JsonParseMappingData* data = mem::new(JsonParseMappingData);

	bench.data = data;
	bench.prepare = (PrepareFn)&json_parse_mapping_prepare;
	bench.run = (RunFn)&json_parse_mapping_run;
	bench.checksum = (ChecksumFn)&json_parse_mapping_checksum;
	bench.cleanup = (CleanupFn)&json_parse_mapping_cleanup;

	return bench;
}