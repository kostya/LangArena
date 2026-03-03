module logparser

import benchmark
import helper
import strings
import srackham.pcre2

pub struct LogParser {
	benchmark.BaseBenchmark
mut:
	lines_count  int
	log          string
	checksum_val u32
	patterns     []pcre2.Regex
}

const pattern_names = [
	'errors',
	'bots',
	'suspicious',
	'ips',
	'api_calls',
	'post_requests',
	'auth_attempts',
	'methods',
	'emails',
	'passwords',
	'tokens',
	'sessions',
	'peak_hours',
]

const pattern_strs = [
	' [5][0-9]{2} | [4][0-9]{2} ',
	'(?i)bot|crawler|scanner|spider|indexing|crawl|robot|spider',
	'(?i)etc/passwd|wp-admin|\\.\\./',
	'\\d+\\.\\d+\\.\\d+\\.35',
	'/api/[^ " ]+',
	'POST [^ ]* HTTP',
	'(?i)/login|/signin',
	'(?i)get|post|put',
	'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}',
	'password=[^&\\s"]+',
	'token=[^&\\s"]+|api[_-]?key=[^&\\s"]+',
	'session[_-]?id=[^&\\s"]+',
	'\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]',
]

const methods = ['GET', 'POST', 'PUT', 'DELETE']
const paths = [
	'/index.html',
	'/api/users',
	'/admin',
	'/images/logo.png',
	'/etc/passwd',
	'/wp-admin/setup.php',
]
const statuses = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
const agents = ['Mozilla/5.0', 'Googlebot/2.1', 'curl/7.68.0', 'scanner/2.0']
const users = ['john', 'jane', 'alex', 'sarah', 'mike', 'anna', 'david', 'elena']
const domains = ['example.com', 'gmail.com', 'yahoo.com', 'hotmail.com', 'company.org', 'mail.ru']

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
		patterns:      []pcre2.Regex{}
	}
	return bench
}

pub fn (b LogParser) name() string {
	return 'Etc::LogParser'
}

fn generate_log_line(i int, ips []string) string {
	mut line := strings.new_builder(200)

	line.write_string(ips[i % ips.len])
	line.write_string(' - - [${i % 31}/Oct/2023:${i % 60}:55:36 +0000] "')
	line.write_string(methods[i % methods.len])
	line.write_string(' ')

	if i % 3 == 0 {
		line.write_string('/login?email=${users[i % users.len]}${i % 100}@${domains[i % domains.len]}&password=secret${i % 10000}')
	} else if i % 5 == 0 {
		line.write_string('/api/data?token=')
		for _ in 0 .. (i % 3) + 1 {
			line.write_string('abcdef123456')
		}
	} else if i % 7 == 0 {
		line.write_string('/user/profile?session_id=sess_${(i * 12345).hex()}')
	} else {
		line.write_string(paths[i % paths.len])
	}

	line.write_string(' HTTP/1.1" ${statuses[i % statuses.len]} 2326 "http://${domains[i % domains.len]}" "${agents[i % agents.len]}"\n')

	return line.str()
}

pub fn (mut p LogParser) prepare() {
	ips := init_ips()
	mut log_builder := strings.new_builder(p.lines_count * 200)

	for i in 0 .. p.lines_count {
		log_builder.write_string(generate_log_line(i, ips))
	}

	p.log = log_builder.str()

	for pattern_str in pattern_strs {
		re := pcre2.compile(pattern_str) or { panic('Failed to compile regex: ${pattern_str}') }
		p.patterns << re
	}
}

pub fn (mut p LogParser) run(iteration_id int) {
	mut matches := map[string]int{}

	for i, name in pattern_names {
		re := p.patterns[i]
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
