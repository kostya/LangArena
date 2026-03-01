package benchmark

import "core:fmt"
import "core:strings"
import "core:text/regex"

LOG_PATTERN_NAMES := [?]string{
    "errors",
    "bots",
    "suspicious",
    "ips",
    "api_calls",
    "post_requests",
    "auth_attempts",
    "methods",
}

LOG_PATTERNS := [?]string{
    " [5][0-9]{2} ",
    "bot|crawler|scanner",
    "etc/passwd|wp-admin|\\.\\./",
    "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35",
    "/api/[^ \"]+",
    "POST /[^ ]* HTTP",
    "/login|/signin",
    "get|post",
}

LOG_PATTERN_FLAGS := [?]int{
    0, 
    1, 
    1, 
    0, 
    0, 
    0, 
    1, 
    1, 
}

METHODS := [?]string{"GET", "POST", "PUT", "DELETE"}
PATHS := [?]string{
    "/index.html", "/api/users", "/login", "/admin",
    "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php",
}
STATUSES := [?]int{200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503}
AGENTS := [?]string{
    "Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0",
}

CompiledPattern :: struct {
    name:  string,
    regex: regex.Regular_Expression,
    valid: bool,
}

LogParser :: struct {
    using base:      Benchmark,
    lines_count:     int,
    log:             string,
    checksum_val:    u32,
    compiled_patterns: []CompiledPattern,
}

write_ip :: proc(sb: ^strings.Builder, i: int) {
    num := (i % 255) + 1
    strings.write_string(sb, "192.168.1.")

    if num < 10 {
        strings.write_byte(sb, byte('0' + num))
    } else if num < 100 {
        strings.write_byte(sb, byte('0' + num / 10))
        strings.write_byte(sb, byte('0' + num % 10))
    } else {
        strings.write_byte(sb, byte('0' + num / 100))
        strings.write_byte(sb, byte('0' + (num / 10) % 10))
        strings.write_byte(sb, byte('0' + num % 10))
    }
}

write_day :: proc(sb: ^strings.Builder, i: int) {
    day := i % 31 + 1
    if day < 10 {
        strings.write_byte(sb, '0')
        strings.write_byte(sb, byte('0' + day))
    } else {
        strings.write_byte(sb, byte('0' + day / 10))
        strings.write_byte(sb, byte('0' + day % 10))
    }
}

write_status :: proc(sb: ^strings.Builder, status: int) {
    strings.write_byte(sb, byte('0' + status / 100))
    strings.write_byte(sb, byte('0' + (status / 10) % 10))
    strings.write_byte(sb, byte('0' + status % 10))
}

compile_patterns :: proc() -> []CompiledPattern {
    count := len(LOG_PATTERNS)
    patterns := make([]CompiledPattern, count)

    for i in 0..<count {
        pattern := LOG_PATTERNS[i]
        flags := LOG_PATTERN_FLAGS[i]

        re, err := regex.create(pattern, { .Case_Insensitive } if flags == 1 else {})

        patterns[i] = CompiledPattern{
            name = LOG_PATTERN_NAMES[i],
            regex = re,
            valid = err == nil,
        }

        if err != nil {
            fmt.printf("Warning: Error compiling pattern %s: %v\n", pattern, err)
        }
    }

    return patterns
}

destroy_patterns :: proc(patterns: []CompiledPattern) {
    for p in patterns {
        if p.valid {
            regex.destroy_regex(p.regex)
        }
    }
    delete(patterns)
}

logparser_prepare :: proc(bench: ^Benchmark) {
    parser := cast(^LogParser)bench
    parser.lines_count = int(config_i64(parser.name, "lines_count"))

    parser.compiled_patterns = compile_patterns()

    sb := strings.builder_make(0, parser.lines_count * 150)

    for i in 0..<parser.lines_count {
        write_ip(&sb, i)
        strings.write_string(&sb, " - - [")
        write_day(&sb, i)
        strings.write_string(&sb, "/Oct/2023:13:55:36 +0000] \"")
        strings.write_string(&sb, METHODS[i % len(METHODS)])
        strings.write_byte(&sb, ' ')
        strings.write_string(&sb, PATHS[i % len(PATHS)])
        strings.write_string(&sb, " HTTP/1.0\" ")
        write_status(&sb, STATUSES[i % len(STATUSES)])
        strings.write_string(&sb, " 2326 \"-\" \"")
        strings.write_string(&sb, AGENTS[i % len(AGENTS)])
        strings.write_string(&sb, "\"\n")
    }

    parser.log = strings.to_string(sb)
    parser.checksum_val = 0
}

logparser_run :: proc(bench: ^Benchmark, iteration_id: int) {
    parser := cast(^LogParser)bench

    matches := make(map[string]int)
    defer delete(matches)

    for j in 0..<len(parser.compiled_patterns) {
        p := parser.compiled_patterns[j]
        if !p.valid do continue

        count := 0
        pos := 0

        for pos < len(parser.log) {
            capture, ok := regex.match(p.regex, parser.log[pos:])
            if !ok do break

            count += 1
            if len(capture.pos) > 0 {
                pos += capture.pos[0][1]
            } else {
                pos += 1
            }
        }

        matches[p.name] = count
    }

    total: u32 = 0
    for _, count in matches {
        total += u32(count)
    }
    parser.checksum_val += total
}

logparser_checksum :: proc(bench: ^Benchmark) -> u32 {
    parser := cast(^LogParser)bench
    return parser.checksum_val
}

logparser_cleanup :: proc(bench: ^Benchmark) {
    parser := cast(^LogParser)bench

    delete(parser.log)
    destroy_patterns(parser.compiled_patterns)
    parser.checksum_val = 0
}

create_logparser :: proc() -> ^Benchmark {
    bench := new(LogParser)
    bench.name = "Etc::LogParser"
    bench.vtable = default_vtable()

    bench.vtable.prepare = logparser_prepare
    bench.vtable.run = logparser_run
    bench.vtable.checksum = logparser_checksum
    bench.vtable.cleanup = logparser_cleanup

    return cast(^Benchmark)bench
}