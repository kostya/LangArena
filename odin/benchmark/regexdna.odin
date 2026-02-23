package benchmark

import "core:fmt"
import "core:strings"
import "core:text/regex"

PATTERNS :: [?]string{
    "agggtaaa|tttaccct",
    "[cgt]gggtaaa|tttaccc[acg]",
    "a[act]ggtaaa|tttacc[agt]t",
    "ag[act]gtaaa|tttac[agt]ct",
    "agg[act]taaa|ttta[agt]cct",
    "aggg[acg]aaa|ttt[cgt]ccct",
    "agggt[cgt]aa|tt[acg]accct",
    "agggta[cgt]a|t[acg]taccct",
    "agggtaa[cgt]|[acg]ttaccct",
}

Replacement :: struct {
    from: string,
    to:   string,
}

REPLACEMENTS :: [?]Replacement{
    {"B", "(c|g|t)"},
    {"D", "(a|g|t)"},
    {"H", "(a|c|t)"},
    {"K", "(g|t)"},
    {"M", "(a|c)"},
    {"N", "(a|c|g|t)"},
    {"R", "(a|g)"},
    {"S", "(c|t)"},
    {"V", "(a|c|g)"},
    {"W", "(a|t)"},
    {"Y", "(c|t)"},
}

RegexDna :: struct {
    using base:   Benchmark,
    seq:          string,
    ilen:         int,
    clen:         int,
    result_buf:   []byte,
    result_len:   int,
}

count_matches :: proc(pattern: string, str: string) -> int {
    re, re_err := regex.create(pattern, flags = {.Case_Insensitive})
    if re_err != nil {
        return 0
    }
    defer regex.destroy_regex(re)

    count := 0
    it, it_err := regex.create_iterator(str, pattern, flags = {.Case_Insensitive})
    if it_err != nil {
        return 0
    }
    defer regex.destroy_iterator(it)

    for {
        capture, _, ok := regex.match_iterator(&it)
        if !ok do break
        count += 1
    }
    return count
}

regex_replace_all :: proc(str, pattern, replacement: string) -> string {
    re, re_err := regex.create(pattern)
    if re_err != nil {
        return str
    }
    defer regex.destroy_regex(re)

    it, it_err := regex.create_iterator(str, pattern)
    if it_err != nil {
        return str
    }
    defer regex.destroy_iterator(it)

    builder: strings.Builder
    offset := 0

    for {
        capture, _, ok := regex.match_iterator(&it)
        if !ok do break

        if len(capture.pos) > 0 {
            start := capture.pos[0][0]
            end := capture.pos[0][1]

            strings.write_string(&builder, str[offset:start])

            strings.write_string(&builder, replacement)

            offset = end
        }
    }

    strings.write_string(&builder, str[offset:])
    return strings.to_string(builder)
}

regexdna_grow_result :: proc(rdna: ^RegexDna, needed: int) {
    min_cap := rdna.result_len + needed + 1
    if min_cap <= len(rdna.result_buf) do return

    new_cap := len(rdna.result_buf) == 0 ? 1024 : len(rdna.result_buf) * 2
    for new_cap < min_cap do new_cap *= 2

    new_buf := make([]byte, new_cap)
    if rdna.result_len > 0 {
        copy(new_buf, rdna.result_buf[:rdna.result_len])
    }

    if rdna.result_buf != nil {
        delete(rdna.result_buf)
    }

    rdna.result_buf = new_buf
}

regexdna_append :: proc(rdna: ^RegexDna, str: string) {
    regexdna_grow_result(rdna, len(str))
    copy(rdna.result_buf[rdna.result_len:], str)
    rdna.result_len += len(str)
}

regexdna_prepare :: proc(bench: ^Benchmark) {
    rdna := cast(^RegexDna)bench

    n := config_i64(rdna.name, "n")

    rdna.result_len = 0
    rdna.result_buf = nil

    fasta_bench := create_fasta()
    defer destroy_bench(fasta_bench)

    fasta := cast(^Fasta)fasta_bench
    fasta.n = int(n)

    fasta_prepare(fasta_bench)
    fasta_run(fasta_bench, 0)

    fasta_result := fasta_get_result(fasta_bench)
    defer delete(fasta_result)

    lines := strings.split_lines(fasta_result)
    defer delete(lines)

    seq_builder := strings.builder_make()
    defer strings.builder_destroy(&seq_builder)

    rdna.ilen = 0

    for line in lines {
        rdna.ilen += len(line) + 1

        if strings.has_prefix(line, ">") {
            continue
        }

        if len(line) > 0 {
            strings.write_string(&seq_builder, line)
        }
    }

    if rdna.ilen > 0 {
        rdna.ilen -= 1
    }

    rdna.seq = strings.clone(strings.to_string(seq_builder))
    rdna.clen = len(rdna.seq)
}

regexdna_run :: proc(bench: ^Benchmark, iteration_id: int) {
    rdna := cast(^RegexDna)bench

    for pattern in PATTERNS {
        count := count_matches(pattern, rdna.seq)
        regexdna_append(rdna, pattern)
        regexdna_append(rdna, " ")
        regexdna_append(rdna, fmt.tprintf("%d", count))
        regexdna_append(rdna, "\n")
    }

    current_seq := rdna.seq
    temp_seqs: [dynamic]string
    defer {
        for seq in temp_seqs {
            delete(seq)
        }
        delete(temp_seqs)
    }

    for repl in REPLACEMENTS {

        if current_seq != rdna.seq {
            append(&temp_seqs, current_seq)
        }

        new_seq := regex_replace_all(current_seq, repl.from, repl.to)
        current_seq = new_seq
    }

    if current_seq != rdna.seq {
        append(&temp_seqs, current_seq)
    }

    regexdna_append(rdna, "\n")
    regexdna_append(rdna, fmt.tprintf("%d", rdna.ilen))
    regexdna_append(rdna, "\n")
    regexdna_append(rdna, fmt.tprintf("%d", rdna.clen))
    regexdna_append(rdna, "\n")
    regexdna_append(rdna, fmt.tprintf("%d", len(current_seq)))
    regexdna_append(rdna, "\n")
}

regexdna_checksum :: proc(bench: ^Benchmark) -> u32 {
    rdna := cast(^RegexDna)bench
    if rdna.result_len == 0 do return 0
    result_str := string(rdna.result_buf[:rdna.result_len])
    return checksum_string(result_str)
}

regexdna_cleanup :: proc(bench: ^Benchmark) {
    rdna := cast(^RegexDna)bench
    delete(rdna.seq)
    delete(rdna.result_buf)
    rdna.result_len = 0
    rdna.ilen = 0
    rdna.clen = 0
}

create_regexdna :: proc() -> ^Benchmark {
    bench := new(RegexDna)
    bench.name = "CLBG::RegexDna"
    bench.vtable = default_vtable()

    bench.vtable.run = regexdna_run
    bench.vtable.checksum = regexdna_checksum
    bench.vtable.prepare = regexdna_prepare
    bench.vtable.cleanup = regexdna_cleanup

    return cast(^Benchmark)bench
}