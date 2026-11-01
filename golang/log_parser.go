package main

import (
	"fmt"
	regexp "github.com/coregx/coregex"
	"strings"
)

type LogParser struct {
	BaseBenchmark
	linesCount  int
	log         string
	checksumVal uint32
	ips         []string
	methods     []string
	paths       []string
	statuses    []int
	agents      []string
	users       []string
	domains     []string
	patterns    []struct {
		name string
		re   *regexp.Regexp
	}
}

func (p *LogParser) initData() {
	p.ips = make([]string, 255)
	for i := 0; i < 255; i++ {
		p.ips[i] = fmt.Sprintf("192.168.1.%d", i+1)
	}

	p.methods = []string{"GET", "POST", "PUT", "DELETE"}
	p.paths = []string{
		"/index.html", "/api/users", "/admin",
		"/images/logo.png", "/etc/passwd", "/wp-admin/setup.php",
	}
	p.statuses = []int{200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503}
	p.agents = []string{
		"Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0",
	}
	p.users = []string{
		"john", "jane", "alex", "sarah", "mike", "anna", "david", "elena",
	}
	p.domains = []string{
		"example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru",
	}
}

func (p *LogParser) compilePatterns() {
	patterns := []struct {
		name string
		re   string
	}{
		{"errors", ` [5][0-9]{2} | [4][0-9]{2} `},
		{"bots", `(?i)bot|crawler|scanner|spider|indexing|crawl|robot|spider`},
		{"suspicious", `(?i)etc/passwd|wp-admin|\.\./`},
		{"ips", `\d+\.\d+\.\d+\.35`},
		{"api_calls", `/api/[^ " ]+`},
		{"post_requests", `POST [^ ]* HTTP`},
		{"auth_attempts", `(?i)/login|/signin`},
		{"methods", `(?i)get|post|put`},
		{"emails", `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`},
		{"passwords", `password=[^&\s"]+`},
		{"tokens", `token=[^&\s"]+|api[_-]?key=[^&\s"]+`},
		{"sessions", `session[_-]?id=[^&\s"]+`},
		{"peak_hours", `\[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]`},
	}

	p.patterns = make([]struct {
		name string
		re   *regexp.Regexp
	}, len(patterns))

	for i, pat := range patterns {
		p.patterns[i] = struct {
			name string
			re   *regexp.Regexp
		}{
			name: pat.name,
			re:   regexp.MustCompile(pat.re),
		}
	}
}

func (p *LogParser) Prepare() {
	p.linesCount = int(p.ConfigVal("lines_count"))

	p.initData()
	p.compilePatterns()

	var builder strings.Builder
	builder.Grow(p.linesCount * 200)

	for i := 0; i < p.linesCount; i++ {
		builder.WriteString(p.generateLogLine(i))
	}

	p.log = builder.String()
}

func (p *LogParser) generateLogLine(i int) string {
	var builder strings.Builder

	builder.WriteString(p.ips[i%len(p.ips)])
	builder.WriteString(fmt.Sprintf(" - - [%d/Oct/2023:%d:55:36 +0000] \"", i%31, i%60))
	builder.WriteString(p.methods[i%len(p.methods)])
	builder.WriteString(" ")

	if i%3 == 0 {
		builder.WriteString(fmt.Sprintf("/login?email=%s%d@%s&password=secret%d",
			p.users[i%len(p.users)], i%100,
			p.domains[i%len(p.domains)], i%10000))
	} else if i%5 == 0 {
		builder.WriteString("/api/data?token=")
		for j := 0; j < (i%3)+1; j++ {
			builder.WriteString("abcdef123456")
		}
	} else if i%7 == 0 {
		builder.WriteString(fmt.Sprintf("/user/profile?session_id=sess_%x", i*12345))
	} else {
		builder.WriteString(p.paths[i%len(p.paths)])
	}

	builder.WriteString(fmt.Sprintf(" HTTP/1.1\" %d 2326 \"http://%s\" \"%s\"\n",
		p.statuses[i%len(p.statuses)],
		p.domains[i%len(p.domains)],
		p.agents[i%len(p.agents)]))

	return builder.String()
}

func (p *LogParser) Run(iteration_id int) {
	matches := make(map[string]int)

	for _, pattern := range p.patterns {
		matches[pattern.name] = len(pattern.re.FindAllStringIndex(p.log, -1))
	}

	total := 0
	for _, count := range matches {
		total += count
	}
	p.checksumVal += uint32(total)
}

func (p *LogParser) Checksum() uint32 {
	return p.checksumVal
}
