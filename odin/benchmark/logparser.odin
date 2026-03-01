package benchmark

import "core:fmt"
import "core:strings"
import "core:mem"
import "core:c"

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
    "(?i)bot|crawler|scanner",
    "(?i)etc/passwd|wp-admin|\\.\\./",
    "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35",
    "/api/[^ \"]+",
    "POST /[^ ]* HTTP",
    "(?i)/login|/signin",
    "(?i)get|post",
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

PCRE2_UTF           :: 0x00080000
PCRE2_NO_UTF_CHECK  :: 0x40000000
PCRE2_JIT_COMPLETE  :: 0x00000001
PCRE2_ERROR_NOMATCH :: -1

PCRE2_CODE :: struct{}
PCRE2_MATCH_DATA :: struct{}

foreign import pcre2 "system:pcre2-8"

@(default_calling_convention="c")
foreign pcre2 {
    pcre2_compile_8 :: proc(
        pattern: cstring,
        length: c.size_t,
        options: u32,
        errorcode: ^c.int,
        erroroffset: ^c.size_t,
        ccontext: rawptr,
    ) -> ^PCRE2_CODE ---

    pcre2_code_free_8 :: proc(code: ^PCRE2_CODE) ---

    pcre2_jit_compile_8 :: proc(code: ^PCRE2_CODE, options: u32) -> c.int ---

    pcre2_match_data_create_from_pattern_8 :: proc(
        code: ^PCRE2_CODE,
        gcontext: rawptr,
    ) -> ^PCRE2_MATCH_DATA ---

    pcre2_match_data_free_8 :: proc(match_data: ^PCRE2_MATCH_DATA) ---

    pcre2_get_ovector_pointer_8 :: proc(match_data: ^PCRE2_MATCH_DATA) -> [^]c.size_t ---

    pcre2_jit_match_8 :: proc(
        code: ^PCRE2_CODE,
        subject: cstring,
        length: c.size_t,
        startoffset: c.size_t,
        options: u32,
        match_data: ^PCRE2_MATCH_DATA,
        mcontext: rawptr,
    ) -> c.int ---
}

CompiledPattern :: struct {
    name:       string,
    code:       ^PCRE2_CODE,
    match_data: ^PCRE2_MATCH_DATA,
    valid:      bool,
}

LogParser :: struct {
    using base:         Benchmark,
    lines_count:        int,
    log:                string,
    checksum_val:       u32,
    compiled_patterns:  [len(LOG_PATTERNS)]CompiledPattern,
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

compile_patterns :: proc() -> (patterns: [len(LOG_PATTERNS)]CompiledPattern) {
    for i in 0..<len(LOG_PATTERNS) {
        pattern := LOG_PATTERNS[i]
        patterns[i].name = LOG_PATTERN_NAMES[i]

        error_number: c.int
        error_offset: c.size_t

        c_pattern := strings.clone_to_cstring(pattern)
        defer delete(c_pattern)

        code := pcre2_compile_8(
            c_pattern,
            c.size_t(len(pattern)),  
            PCRE2_UTF | PCRE2_NO_UTF_CHECK,
            &error_number,
            &error_offset,
            nil,
        )

        if code == nil {
            fmt.printf("Warning: Error compiling pattern %s\n", pattern)
            patterns[i].valid = false
            continue
        }

        pcre2_jit_compile_8(code, PCRE2_JIT_COMPLETE)

        match_data := pcre2_match_data_create_from_pattern_8(code, nil)
        if match_data == nil {
            pcre2_code_free_8(code)
            patterns[i].valid = false
            continue
        }

        patterns[i].code = code
        patterns[i].match_data = match_data
        patterns[i].valid = true
    }
    return
}

destroy_patterns :: proc(patterns: [len(LOG_PATTERNS)]CompiledPattern) {
    for p in patterns {
        if p.valid {
            if p.match_data != nil {
                pcre2_match_data_free_8(p.match_data)
            }
            if p.code != nil {
                pcre2_code_free_8(p.code)
            }
        }
    }
}

count_pattern :: proc(parser: ^LogParser, pattern_idx: int) -> int {
    p := parser.compiled_patterns[pattern_idx]
    if !p.valid do return 0

    count := 0
    start_offset: c.size_t = 0
    subject := strings.clone_to_cstring(parser.log)
    defer delete(subject)
    subject_length := c.size_t(len(parser.log))

    for {
        rc := pcre2_jit_match_8(
            p.code,
            subject,
            subject_length,
            start_offset,
            0,
            p.match_data,
            nil,
        )

        if rc < 0 {
            if rc == PCRE2_ERROR_NOMATCH do break
            break
        }

        count += 1

        ovector := pcre2_get_ovector_pointer_8(p.match_data)
        start_offset = ovector[1]
    }

    return count
}

logparser_prepare :: proc(bench: ^Benchmark) {
    parser := cast(^LogParser)bench
    parser.lines_count = int(config_i64(parser.name, "lines_count"))

    parser.compiled_patterns = compile_patterns()

    sb := strings.builder_make(0, parser.lines_count * 150)
    defer strings.builder_destroy(&sb)

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

    parser.log = strings.clone(strings.to_string(sb))
    parser.checksum_val = 0
}

logparser_run :: proc(bench: ^Benchmark, iteration_id: int) {
    parser := cast(^LogParser)bench

    matches := make(map[string]int)
    defer delete(matches)

    for i in 0..<len(LOG_PATTERNS) {
        count := count_pattern(parser, i)
        matches[LOG_PATTERN_NAMES[i]] = count
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