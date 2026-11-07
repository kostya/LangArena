module csv_bench;

import benchmark;
import helper;
import std::io;
import std::collections::list;

struct Point
{
	double x, y, z;
}

fn double parse_field_value(String field)
{
	field = field.strip_suffix("\"").strip_prefix("\"");
	return field.to_double() ?? 0;
}

fn bool is_numeric_field(int idx) => idx == 1 || idx == 3 || idx == 5;

fn int parse_points(String csv_data, List{Point}* points)
{
	int field_idx    = 0;
	usz field_start  = 0;
	bool in_quotes   = false;
	double[6] values = { 0, 0, 0, 0, 0, 0 };

	usz pos = 0;
	while (pos < csv_data.len)
	{
		char ch = csv_data[pos];

		if (ch == '"')
		{
			if (in_quotes && pos + 1 < csv_data.len && csv_data[pos + 1] == '"')
			{
				pos += 2;
				continue;
			}
			in_quotes = !in_quotes;
			pos++;
		}
		else if (ch == ',' && !in_quotes)
		{
			if (is_numeric_field(field_idx))
			{
				String field = csv_data[field_start:pos - field_start];
				values[field_idx] = parse_field_value(field);
			}
			field_idx++;
			field_start = pos + 1;
			pos++;
		}
		else if (ch == '\n' && !in_quotes)
		{
			if (field_idx < 6)
			{
				if (is_numeric_field(field_idx))
				{
					String field = csv_data[field_start:pos - field_start];
					values[field_idx] = parse_field_value(field);
				}
				field_idx++;
			}

			if (field_idx >= 6)
			{
				points.push({ .x = values[1], .y = values[5], .z = values[3] });
			}

			field_idx = 0;
			field_start = pos + 1;
			pos++;
		}
		else
		{
			pos++;
		}
	}

	if (field_start < pos && field_idx > 0)
	{
		if (field_idx < 6)
		{
			if (is_numeric_field(field_idx))
			{
				String field = csv_data[field_start:pos - field_start];
				values[field_idx] = parse_field_value(field);
			}
			field_idx++;
		}

		if (field_idx >= 6)
		{
			points.push({ .x = values[1], .y = values[5], .z = values[3] });
		}
	}

	return (int)points.len();
}

struct CsvParseData
{
	char[] csv_data;
	uint result_val;
	long rows;
}

fn char[] generate_csv_for_parsing(long rows)
{
	DString buffer;
	buffer.init(mem, (usz)(rows * 100 + 1));
	defer buffer.free();

	for (long i = 0; i < rows; i++)
	{
		char c   = (char)('A' + (i % 26));
		double x = helper::helper_next_float(1.0);
		double z = helper::helper_next_float(1.0);
		double y = helper::helper_next_float(1.0);

		String bool_str = (i % 2 == 0) ? "true" : "false";

		buffer.appendf(
			"\"point %c\\n, \"\"%d\"\"\",%.10f,,%.10f,\"[%s\\n, %d]\",%.10f\n",
			c,
			(int)(i % 100),
			x,
			z,
			bool_str,
			(int)(i % 100),
			y
		);
	}

	return buffer.copy_str(mem);
}

fn void csv_parse_prepare(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	data.rows = helper::helper_config_i64(self.name, "rows");
	data.csv_data = generate_csv_for_parsing(data.rows);
}

fn void csv_parse_run(Benchmark* self, int iteration_id)
{
	CsvParseData* data = (CsvParseData*)self.data;
	if (data.csv_data.len == 0) return;

	List{Point} points;
	points.init(mem);
	defer points.free();

	int point_count = parse_points((String)data.csv_data, &points);

	if (point_count > 0)
	{
		double x_sum = 0;
		double y_sum = 0;
		double z_sum = 0;
		foreach (p : points)
		{
			x_sum += p.x;
			y_sum += p.y;
			z_sum += p.z;
		}

		double len = (double)points.len();
		data.result_val += helper::helper_checksum_f64(
			x_sum / len
		) + helper::helper_checksum_f64(y_sum / len) + helper::helper_checksum_f64(z_sum / len);
	}
}

fn uint csv_parse_checksum(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	return data.result_val + helper::helper_checksum_string((String)data.csv_data);
}

fn void csv_parse_cleanup(Benchmark* self)
{
	CsvParseData* data = (CsvParseData*)self.data;
	free(data.csv_data);
	data.csv_data = { };
}

fn Benchmark* csv_parse_create() @cname("CsvParse_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("CSV::Parse");

	CsvParseData* data = mem::new(CsvParseData);

	bench.data = data;
	bench.prepare = (PrepareFn)&csv_parse_prepare;
	bench.run = (RunFn)&csv_parse_run;
	bench.checksum = (ChecksumFn)&csv_parse_checksum;
	bench.cleanup = (CleanupFn)&csv_parse_cleanup;

	return bench;
}