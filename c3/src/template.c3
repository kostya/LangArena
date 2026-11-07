module template_bench;

import benchmark;
import helper;
import std::io;
import std::collections::map;

extern fn void* pcre2_compile(
	char* pattern,
	usz len,
	uint options,
	int* errnumber,
	usz* erroroffset,
	void* ccontext
) @cname("pcre2_compile_8");
extern fn int pcre2_jit_compile(void* code, uint options) @cname("pcre2_jit_compile_8");
extern fn void* pcre2_match_data_create_from_pattern(
	void* code,
	void* ccontext
) @cname("pcre2_match_data_create_from_pattern_8");
extern fn int pcre2_jit_match(
	void* code,
	char* subject,
	usz len,
	usz start_offset,
	uint options,
	void* match_data,
	void* mcontext
) @cname("pcre2_jit_match_8");
extern fn usz* pcre2_get_ovector_pointer(void* match_data) @cname("pcre2_get_ovector_pointer_8");
extern fn void pcre2_code_free(void* code) @cname("pcre2_code_free_8");
extern fn void pcre2_match_data_free(void* match_data) @cname("pcre2_match_data_free_8");

const uint PCRE2_UTF          = 0x00080000;
const uint PCRE2_NO_UTF_CHECK = 0x40000000;
const uint PCRE2_JIT_COMPLETE = 0x00000001;

const String[8] FIRST_NAMES         = { "John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike" };
const String[8] LAST_NAMES          = { "Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones" };
const String[6] CITIES              = { "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco" };
const String LOREM                  = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. ";
const String TEMPLATE_REGEX_PATTERN = "{{(.*?)}}";

struct TemplateBaseData
{
	int count;
	uint checksum_val;
	char* text;
	usz text_size;
	char* rendered;
	usz rendered_size;
	HashMap{String, String} vars;
}

fn void add_var(TemplateBaseData* data, String key, String value)
{
	data.vars.set(key, value);
}

fn String get_var(TemplateBaseData* data, String key)
{
	String? val = data.vars.get(key);
	if (try v = val) return v;
	return "";
}

fn int prepare_template(TemplateBaseData* data)
{
	free(data.text);
	data.text = null;
	data.vars.clear();

	DString buf;
	buf.init(mem, (usz)(data.count * 200 + 1));

	buf.append("<html><body>");
	buf.append("<h1>{{TITLE}}</h1>");
	add_var(data, "TITLE", "Template title");
	buf.append("<p>");
	buf.append(LOREM);
	buf.append("</p>");
	buf.append("<table>");

	for (int i = 0; i < data.count; i++)
	{
		if (i % 3 == 0)
		{
			buf.append("<!-- {comment} -->");
		}

		buf.append("<tr>");
		buf.append("<td>{{ FIRST_NAME");
		buf.appendf("%d", i);
		buf.append(" }}</td>");
		String key = string::tformat("FIRST_NAME%d", i).copy(mem);
		add_var(data, key, FIRST_NAMES[i % 8]);

		buf.append("<td>{{LAST_NAME");
		buf.appendf("%d", i);
		buf.append("}}</td>");
		key = string::tformat("LAST_NAME%d", i).copy(mem);
		add_var(data, key, LAST_NAMES[i % 8]);

		buf.append("<td>{{  CITY");
		buf.appendf("%d", i);
		buf.append("  }}</td>");
		key = string::tformat("CITY%d", i).copy(mem);
		add_var(data, key, CITIES[i % 6]);

		buf.appendf("<td>{balance: %d}</td>", i % 100);
		buf.append("</tr>\n");
	}

	buf.append("</table>");
	buf.append("</body></html>");

	String result = buf.str_view();
	data.text = mem::new_array(char, result.len + 1);
	mem::copy(data.text, (char*)result, result.len);
	data.text[result.len] = 0;
	data.text_size = result.len;
	buf.free();
	return 0;
}

struct TemplateRegexData
{
	TemplateBaseData base;
	void* re;
	void* match_data;
}

fn void template_regex_prepare(Benchmark* self)
{
	TemplateRegexData* data = (TemplateRegexData*)self.data;
	data.base.count = (int)helper::helper_config_i64(self.name, "count");
	prepare_template(&data.base);

	if (!data.re)
	{
		int errornumber;
		usz erroroffset;
		data.re = pcre2_compile(
			(char*)TEMPLATE_REGEX_PATTERN,
			TEMPLATE_REGEX_PATTERN.len,
			PCRE2_UTF | PCRE2_NO_UTF_CHECK,
			&errornumber,
			&erroroffset,
			null
		);
		if (data.re)
		{
			pcre2_jit_compile(data.re, PCRE2_JIT_COMPLETE);
			data.match_data = pcre2_match_data_create_from_pattern(data.re, null);
		}
	}
}

fn void template_regex_run(Benchmark* self, int iteration_id)
{
	TemplateRegexData* data = (TemplateRegexData*)self.data;
	TemplateBaseData* base  = &data.base;

	if (!data.re || !data.match_data || !base.text) return;

	DString result_buf;
	result_buf.init(mem, (sz)base.text_size * 2);
	defer result_buf.free();

	usz start_offset = 0;
	usz last_pos     = 0;

	while (true)
	{
		int rc = pcre2_jit_match(data.re, base.text, base.text_size, start_offset, 0, data.match_data, null);
		if (rc < 0) break;

		usz* ovector    = pcre2_get_ovector_pointer(data.match_data);
		usz match_start = ovector[0];
		usz match_end   = ovector[1];

		if (match_start > last_pos)
		{
			result_buf.append((String)base.text[last_pos:match_start - last_pos]);
		}

		usz key_start = ovector[2];
		usz key_end   = ovector[3];

		if (key_end > key_start)
		{
			usz key_len    = key_end - key_start;
			String raw_key = (String)base.text[key_start:key_len];
			String key     = raw_key.trim();

			String value = get_var(base, key);
			if (value.len > 0)
			{
				result_buf.append(value);
			}
		}

		last_pos = match_end;
		start_offset = match_end;
		if (start_offset >= base.text_size) break;
	}

	if (last_pos < base.text_size)
	{
		result_buf.append((String)base.text[last_pos:base.text_size - last_pos]);
	}

	String result = result_buf.str_view();
	free(base.rendered);
	base.rendered = mem::new_array(char, result.len + 1);
	mem::copy(base.rendered, (char*)result, result.len);
	base.rendered[result.len] = 0;
	base.rendered_size = result.len;
	base.checksum_val += (uint)base.rendered_size;
}

fn uint template_regex_checksum(Benchmark* self)
{
	TemplateRegexData* data = (TemplateRegexData*)self.data;
	if (!data.base.rendered) return data.base.checksum_val;
	return data.base.checksum_val + helper::helper_checksum_string(((ZString)data.base.rendered).str_view());
}

fn void template_regex_cleanup(Benchmark* self)
{
	TemplateRegexData* data = (TemplateRegexData*)self.data;
	free(data.base.text);
	free(data.base.rendered);
	data.base.vars.free();

	if (data.match_data)
	{
		pcre2_match_data_free(data.match_data);
		data.match_data = null;
	}
	if (data.re)
	{
		pcre2_code_free(data.re);
		data.re = null;
	}
}

fn Benchmark* template_regex_create() @cname("TemplateRegex_create") @export
{
	Benchmark* bench        = benchmark::benchmark_create("Template::Regex");
	TemplateRegexData* data = mem::new(TemplateRegexData);
	data.base.vars.init(mem);

	bench.data = data;
	bench.prepare = (PrepareFn)&template_regex_prepare;
	bench.run = (RunFn)&template_regex_run;
	bench.checksum = (ChecksumFn)&template_regex_checksum;
	bench.cleanup = (CleanupFn)&template_regex_cleanup;

	return bench;
}

struct TemplateParseData
{
	TemplateBaseData base;
}

fn void template_parse_prepare(Benchmark* self)
{
	TemplateParseData* data = (TemplateParseData*)self.data;
	data.base.count = (int)helper::helper_config_i64(self.name, "count");
	prepare_template(&data.base);
}

fn void template_parse_run(Benchmark* self, int iteration_id)
{
	TemplateParseData* data = (TemplateParseData*)self.data;
	TemplateBaseData* base  = &data.base;

	if (!base.text) return;

	DString result_buf;
	result_buf.init(mem, (sz)(base.text_size * 1.5) + 1);
	defer result_buf.free();

	usz i   = 0;
	usz len = base.text_size;

	while (i < len)
	{
		if (i + 1 < len && base.text[i] == '{' && base.text[i + 1] == '{')
		{
			usz j = i + 2;
			while (j + 1 < len)
			{
				if (base.text[j] == '}' && base.text[j + 1] == '}') break;
				j++;
			}

			if (j + 1 < len)
			{
				usz key_len    = j - i - 2;
				String raw_key = (String)base.text[i + 2:key_len];
				String key     = raw_key.trim();

				String value = get_var(base, key);
				if (value.len > 0)
				{
					result_buf.append(value);
				}

				i = j + 2;
				continue;
			}
		}

		result_buf.append_char(base.text[i]);
		i++;
	}

	free(base.rendered);
	String result = result_buf.str_view();
	base.rendered = mem::new_array(char, result.len + 1);
	mem::copy(base.rendered, (char*)result, result.len);
	base.rendered[result.len] = 0;
	base.rendered_size = result.len;
	base.checksum_val += (uint)base.rendered_size;
}

fn uint template_parse_checksum(Benchmark* self)
{
	TemplateParseData* data = (TemplateParseData*)self.data;
	if (!data.base.rendered) return data.base.checksum_val;
	return data.base.checksum_val + helper::helper_checksum_string(((ZString)data.base.rendered).str_view());
}

fn void template_parse_cleanup(Benchmark* self)
{
	TemplateParseData* data = (TemplateParseData*)self.data;
	free(data.base.text);
	free(data.base.rendered);
	data.base.vars.free();
}

fn Benchmark* template_parse_create() @cname("TemplateParse_create") @export
{
	Benchmark* bench        = benchmark::benchmark_create("Template::Parse");
	TemplateParseData* data = mem::new(TemplateParseData);
	data.base.vars.init(mem);

	bench.data = data;
	bench.prepare = (PrepareFn)&template_parse_prepare;
	bench.run = (RunFn)&template_parse_run;
	bench.checksum = (ChecksumFn)&template_parse_checksum;
	bench.cleanup = (CleanupFn)&template_parse_cleanup;

	return bench;
}