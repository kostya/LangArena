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

LogParser :: struct {
    using base:   Benchmark,
    lines_count:  int,
    log:          string,
    checksum_val: u32,
    ips:          []string,  
}

generate_ips :: proc() -> []string {
    ips := make([]string, 255)
    for i in 0..<255 {
        ips[i] = fmt.tprintf("192.168.1.%d", i + 1)
    }
    return ips
}

generate_log_line :: proc(ips: []string, i: int) -> string {
    return fmt.tprintf("%s - - [%d/Oct/2023:13:55:36 +0000] \"%s %s HTTP/1.0\" %d 2326 \"-\" \"%s\"\n",
        ips[i % len(ips)],
        i % 31,
        METHODS[i % len(METHODS)],
        PATHS[i % len(PATHS)],
        STATUSES[i % len(STATUSES)],
        AGENTS[i % len(AGENTS)])
}

logparser_prepare :: proc(bench: ^Benchmark) {
    parser := cast(^LogParser)bench

    parser.lines_count = int(config_i64(parser.name, "lines_count"))
    parser.ips = generate_ips()

    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    for i in 0..<parser.lines_count {
        strings.write_string(&sb, generate_log_line(parser.ips, i))
    }

    parser.log = strings.clone(strings.to_string(sb))
    parser.checksum_val = 0
}

logparser_run :: proc(bench: ^Benchmark, iteration_id: int) {
    parser := cast(^LogParser)bench

    matches := make(map[string]int)
    defer delete(matches)

    for name, i in LOG_PATTERN_NAMES {
        pattern := LOG_PATTERNS[i]
        flag := LOG_PATTERN_FLAGS[i]

        re, re_err := regex.create(pattern, { .Case_Insensitive } if flag == 1 else {})
        if re_err != nil {
            fmt.printf("Error compiling pattern %s: %v\n", pattern, re_err)
            matches[name] = 0
            continue
        }
        defer regex.destroy_regex(re)

        count := 0
        pos := 0

        for pos < len(parser.log) {
            capture, ok := regex.match(re, parser.log[pos:])
            if !ok do break

            count += 1
            if len(capture.pos) > 0 {
                pos += capture.pos[0][1]
            } else {
                pos += 1
            }
        }

        matches[name] = count
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
    delete(parser.ips)  
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