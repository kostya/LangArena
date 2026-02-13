package benchmark

import "core:strings"
import "core:slice"

Revcomp :: struct {
    using base: Benchmark,
    n: i64,
    input: string,
    result_val: u32,
}

LOOKUP_TABLE: [256]byte
IS_INITIALIZED := false

FROM_BYTES := "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
TO_BYTES := "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

init_lookup_table :: proc() {
    if IS_INITIALIZED do return

    for i in 0..<256 {
        LOOKUP_TABLE[i] = byte(i)
    }

    for i in 0..<len(FROM_BYTES) {
        from := FROM_BYTES[i]
        to := TO_BYTES[i]
        LOOKUP_TABLE[from] = to
    }

    IS_INITIALIZED = true
}

revcomp :: proc(seq: string) -> string {
    if len(seq) == 0 {
        return ""
    }

    init_lookup_table()
    n := len(seq)

    bytes := make([]byte, n)

    for i in 0..<n {
        ch := seq[i]
        bytes[n - 1 - i] = LOOKUP_TABLE[ch]
    }

    line_length :: 60

    line_breaks := n / line_length
    if n % line_length > 0 do line_breaks += 1
    total_size := n + line_breaks

    result_buf := make([]byte, total_size)
    pos := 0

    for i := 0; i < n; i += line_length {
        end := min(i + line_length, n)
        chunk_len := end - i
        copy(result_buf[pos:], bytes[i:end])
        pos += chunk_len
        result_buf[pos] = '\n'
        pos += 1
    }

    result := string(result_buf[:pos])
    delete(bytes)

    return result
}

revcomp_run :: proc(bench: ^Benchmark, iteration_id: int) {
    rc := cast(^Revcomp)bench

    result := revcomp(rc.input)
    defer delete(result)

    checksum := checksum_string(result)
    rc.result_val = rc.result_val + checksum
}

revcomp_checksum :: proc(bench: ^Benchmark) -> u32 {
    rc := cast(^Revcomp)bench
    return rc.result_val
}

revcomp_prepare :: proc(bench: ^Benchmark) {
    rc := cast(^Revcomp)bench

    rc.n = config_i64("Revcomp", "n")
    rc.result_val = 0

    fasta_bench := create_fasta()
    defer {
        fasta_cleanup(fasta_bench)
        free(fasta_bench)
    }

    fasta := cast(^Fasta)fasta_bench
    fasta.n = int(rc.n)

    fasta_prepare(fasta_bench)
    fasta_run(fasta_bench, 0)

    fasta_result := fasta_get_result(fasta_bench)
    defer delete(fasta_result)

    lines := strings.split(fasta_result, "\n")
    defer delete(lines)

    total_len := 0
    for line in lines {
        if len(line) == 0 do continue

        if line[0] == '>' {
            total_len += 5  
        } else {
            trimmed := strings.trim_space(line)
            total_len += len(trimmed)
        }
    }

    result_buf := make([]byte, total_len)
    pos := 0

    for line in lines {
        if len(line) == 0 do continue

        if line[0] == '>' {
            copy(result_buf[pos:], "\n---\n")
            pos += 5
        } else {
            trimmed := strings.trim_space(line)
            copy(result_buf[pos:], trimmed)
            pos += len(trimmed)
        }
    }

    rc.input = string(result_buf[:pos])
}

revcomp_cleanup :: proc(bench: ^Benchmark) {
    rc := cast(^Revcomp)bench
    delete(rc.input)
}

create_revcomp :: proc() -> ^Benchmark {
    bench := new(Revcomp)
    bench.name = "Revcomp"
    bench.vtable = default_vtable()

    bench.vtable.run = revcomp_run
    bench.vtable.checksum = revcomp_checksum
    bench.vtable.prepare = revcomp_prepare
    bench.vtable.cleanup = revcomp_cleanup

    return cast(^Benchmark)bench
}