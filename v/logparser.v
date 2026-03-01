module logparser

import benchmark
import helper
import strings
import srackham.pcre2 as pcre

pub struct LogParser {
	benchmark.BaseBenchmark
mut:
	lines_count  int
	log          string
	checksum_val u32
}

const pattern_names = ['errors', 'bots', 'suspicious', 'ips', 'api_calls', 'post_requests',
	'auth_attempts', 'methods']
const pattern_strs = [
	' [5][0-9]{2} ',
	'(?i)bot|crawler|scanner',
	'(?i)etc/passwd|wp-admin|\\.\\./',
	'\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35',
	'/api/[^ "]+',
	'POST [^ ]* HTTP',
	'(?i)/login|/signin',
	'(?i)get|post',
]

const methods = ['GET', 'POST', 'PUT', 'DELETE']
const paths = [
	'/index.html',
	'/api/users',
	'/login',
	'/admin',
	'/images/logo.png',
	'/etc/passwd',
	'/wp-admin/setup.php',
]
const statuses = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
const agents = ['Mozilla/5.0', 'Googlebot/2.1', 'curl/7.68.0', 'scanner/2.0']

fn init_ips() []string {
	mut ips := []string{}
	for i in 1 .. 256 {
		ips << '192.168.1.${i}'
	}
	return ips
}

pub fn new_logparser() &benchmark.IBenchmark {
	mut bench := &LogParser{
		BaseBenchmark: benchmark.new_base_benchmark('Etc::LogParser')
		lines_count:   int(helper.config_i64('Etc::LogParser', 'lines_count'))
		log:           ''
		checksum_val:  0
	}
	return bench
}

pub fn (b LogParser) name() string {
	return 'Etc::LogParser'
}

fn generate_log_line(i int, ips []string) string {
	return '${ips[i % ips.len]} - - [${i % 31}/Oct/2023:13:55:36 +0000] "${methods[i % methods.len]} ${paths[i % paths.len]} HTTP/1.0" ${statuses[i % statuses.len]} 2326 "-" "${agents[i % agents.len]}"\n'
}

pub fn (mut p LogParser) prepare() {
	ips := init_ips()
	mut log_builder := strings.new_builder(p.lines_count * 150)

	for i in 0 .. p.lines_count {
		log_builder.write_string(generate_log_line(i, ips))
	}

	p.log = log_builder.str()
}

pub fn (mut p LogParser) run(iteration_id int) {
	mut matches := map[string]int{}

	for i, name in pattern_names {
		pattern := pattern_strs[i]
		re := pcre.compile(pattern) or { continue }

		matches_cnt := re.find_all(p.log).len
		matches[name] = matches_cnt
	}

	mut total := 0
	for _, count in matches {
		total += count
	}
	p.checksum_val += u32(total)
}

pub fn (mut p LogParser) checksum() u32 {
	return p.checksum_val
}
