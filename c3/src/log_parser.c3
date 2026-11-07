module log_parser;

import benchmark;
import helper;
import std::io;

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

const PATTERNS_COUNT = 13;

const char*[4] METHODS = { "GET", "POST", "PUT", "DELETE" };
const char*[6] PATHS   = {
	"/index.html",
	"/api/users",
	"/admin",
	"/images/logo.png",
	"/etc/passwd",
	"/wp-admin/setup.php"
};
const int[11] STATUSES = { 200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503 };
const char*[4] AGENTS  = { "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0" };
const char*[8] USERS   = { "john", "jane", "alex", "sarah", "mike", "anna", "david", "elena" };
const char*[6] DOMAINS = { "example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru" };

const char*[13] PATTERNS = {
	" [5][0-9]{2} | [4][0-9]{2} ",
	"(?i)bot|crawler|scanner|spider|indexing|crawl|robot|spider",
	"(?i)etc/passwd|wp-admin|\\.\\./",
	"\\d+\\.\\d+\\.\\d+\\.35",
	"/api/[^ \" ]+",
	"POST [^ ]* HTTP",
	"(?i)/login|/signin",
	"(?i)get|post|put",
	"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
	"password=[^&\\s\"]+",
	"token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+",
	"session[_-]?id=[^&\\s\"]+",
	"\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]"
};

fn void generate_log_line(char** ips_list, char* buffer, usz* pos, int i)
{
	if (i % 3 == 0)
	{
		String s = string::tformat(
			"%s - - [%d/Oct/2023:%d:55:36 +0000] \"%s /login?email=%s%d@%s&password=secret%d HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
			(ZString)ips_list[i % 255],
			i % 31,
			i % 60,
			(ZString)METHODS[i % 4],
			(ZString)USERS[i % 8],
			i % 100,
			(ZString)DOMAINS[i % 6],
			i % 10000,
			STATUSES[i % 11],
			(ZString)DOMAINS[i % 6],
			(ZString)AGENTS[i % 4]
		);
		mem::copy(buffer + *pos, (char*)s, s.len);
		*pos += s.len;
	}
	else if (i % 5 == 0)
	{
		char[200] token_buf;
		token_buf[0] = 0;
		for (int j = 0; j < (i % 3) + 1; j++)
		{
			sz len = ((ZString)&token_buf).len();
			mem::copy(&token_buf + len, "abcdef123456", 12);
			token_buf[len + 12] = 0;
		}
		String s = string::tformat(
			"%s - - [%d/Oct/2023:%d:55:36 +0000] \"%s /api/data?token=%s HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
			(ZString)ips_list[i % 255],
			i % 31,
			i % 60,
			(ZString)METHODS[i % 4],
			(ZString)&token_buf,
			STATUSES[i % 11],
			(ZString)DOMAINS[i % 6],
			(ZString)AGENTS[i % 4]
		);
		mem::copy(buffer + *pos, (char*)s, s.len);
		*pos += s.len;
	}
	else if (i % 7 == 0)
	{
		String s = string::tformat(
			"%s - - [%d/Oct/2023:%d:55:36 +0000] \"%s /user/profile?session_id=sess_%x HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
			(ZString)ips_list[i % 255],
			i % 31,
			i % 60,
			(ZString)METHODS[i % 4],
			i * 12345,
			STATUSES[i % 11],
			(ZString)DOMAINS[i % 6],
			(ZString)AGENTS[i % 4]
		);
		mem::copy(buffer + *pos, (char*)s, s.len);
		*pos += s.len;
	}
	else
	{
		String s = string::tformat(
			"%s - - [%d/Oct/2023:%d:55:36 +0000] \"%s %s HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
			(ZString)ips_list[i % 255],
			i % 31,
			i % 60,
			(ZString)METHODS[i % 4],
			(ZString)PATHS[i % 6],
			STATUSES[i % 11],
			(ZString)DOMAINS[i % 6],
			(ZString)AGENTS[i % 4]
		);
		mem::copy(buffer + *pos, (char*)s, s.len);
		*pos += s.len;
	}
}

struct LogParserData
{
	int lines_count;
	char* log;
	usz log_size;
	uint checksum_val;
	void*[13] compiled_patterns;
	void*[13] match_data;
	char*[255] ips_list;
}

fn void log_parser_prepare(Benchmark* self)
{
	LogParserData* data = (LogParserData*)self.data;

	if (!data.ips_list[0])
	{
		for (int i = 0; i < 255; i++)
		{
			char* ip = mem::alloc_array(char, 16);
			String s = string::tformat("192.168.1.%d", i + 1);
			mem::copy(ip, (char*)s, s.len);
			ip[s.len] = 0;
			data.ips_list[i] = ip;
		}
	}

	mem::free(data.log);
	data.log = null;

	data.lines_count = (int)helper::helper_config_i64(self.name, "lines_count");

	char* log_buf = mem::alloc_array(char, (sz)data.lines_count * 200 + 1);

	usz pos = 0;
	for (int i = 0; i < data.lines_count; i++)
	{
		generate_log_line(&data.ips_list, log_buf, &pos, i);
	}
	log_buf[pos] = 0;

	data.log = log_buf;
	data.log_size = pos;

	for (int i = 0; i < PATTERNS_COUNT; i++)
	{
		int errornumber = 0;
		usz erroroffset = 0;

		String pattern_str = ((ZString)PATTERNS[i]).str_view();
		data.compiled_patterns[i] = pcre2_compile(
			PATTERNS[i],
			pattern_str.len,
			PCRE2_NO_UTF_CHECK,
			&errornumber,
			&erroroffset,
			null
		);

		if (data.compiled_patterns[i])
		{
			pcre2_jit_compile(data.compiled_patterns[i], PCRE2_JIT_COMPLETE);
			data.match_data[i] = pcre2_match_data_create_from_pattern(data.compiled_patterns[i], null);
		}
	}
}

fn void log_parser_run(Benchmark* self, int iteration_id)
{
	LogParserData* data = (LogParserData*)self.data;

	int[PATTERNS_COUNT] matches = { };

	for (int i = 0; i < PATTERNS_COUNT; i++)
	{
		if (!data.compiled_patterns[i]) continue;

		usz start_offset = 0;

		while (true)
		{
			int rc = pcre2_jit_match(
				data.compiled_patterns[i],
				data.log,
				data.log_size,
				start_offset,
				PCRE2_NO_UTF_CHECK,
				data.match_data[i],
				null
			);

			if (rc < 0) break;

			matches[i]++;

			usz* ovector = pcre2_get_ovector_pointer(data.match_data[i]);
			start_offset = ovector[1];
			if (start_offset >= data.log_size) break;
		}
	}

	uint total = 0;
	for (int i = 0; i < PATTERNS_COUNT; i++)
	{
		total += (uint)matches[i];
	}
	data.checksum_val += total;
}

fn uint log_parser_checksum(Benchmark* self)
{
	return ((LogParserData*)self.data).checksum_val;
}

fn void log_parser_cleanup(Benchmark* self)
{
	LogParserData* data = (LogParserData*)self.data;

	mem::free(data.log);
	data.log = null;

	for (int i = 0; i < 255; i++)
	{
		if (data.ips_list[i])
		{
			mem::free(data.ips_list[i]);
			data.ips_list[i] = null;
		}
	}

	for (int i = 0; i < PATTERNS_COUNT; i++)
	{
		if (data.compiled_patterns[i])
		{
			pcre2_code_free(data.compiled_patterns[i]);
			data.compiled_patterns[i] = null;
		}
		if (data.match_data[i])
		{
			pcre2_match_data_free(data.match_data[i]);
			data.match_data[i] = null;
		}
	}
}

fn Benchmark* log_parser_create() @cname("LogParser_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::LogParser");

	LogParserData* data = mem::new(LogParserData);

	bench.data = data;
	bench.prepare = (PrepareFn)&log_parser_prepare;
	bench.run = (RunFn)&log_parser_run;
	bench.checksum = (ChecksumFn)&log_parser_checksum;
	bench.cleanup = (CleanupFn)&log_parser_cleanup;

	return bench;
}