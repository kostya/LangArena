package benchmark

import "core:fmt"
import "core:strings"
import "core:slice"

Frequency_Entry :: struct {
    key:   string,
    count: int,
}

frequency :: proc(seq: string, length: int, allocator := context.allocator) -> (n: int, table: map[string]int) {
    if len(seq) == 0 || length <= 0 {
        return 0, make(map[string]int, allocator)
    }

    n = len(seq) - length + 1
    if n <= 0 { return 0, make(map[string]int, allocator) }

    table = make(map[string]int, allocator)

    for i in 0..<n {
        sub := seq[i:i + length]
        table[sub] += 1
    }

    return n, table
}

Knuckeotide :: struct {
    using base: Benchmark,
    n: int,
    sequence: string,
    result_str: string,  
}

knuckeotide_prepare :: proc(bench: ^Benchmark) {
    kn := cast(^Knuckeotide)bench
    kn.n = int(config_i64("CLBG::Knuckeotide", "n"))

    fasta_bench := create_fasta()
    defer destroy_bench(fasta_bench)

    fasta := cast(^Fasta)fasta_bench
    fasta.n = kn.n

    fasta_prepare(fasta_bench)
    fasta_run(fasta_bench, 0)

    fasta_result := fasta_get_result(fasta_bench)
    defer delete(fasta_result)

    lines := strings.split_lines(fasta_result)
    defer delete(lines)

    seq_builder := strings.builder_make()
    defer strings.builder_destroy(&seq_builder)

    three_section := false

    for line in lines {
        if strings.has_prefix(line, ">THREE") {
            three_section = true
            continue
        }

        if three_section {

            if len(line) > 0 && line[0] == '>' {
                break
            }

            trimmed := strings.trim_space(line)
            strings.write_string(&seq_builder, trimmed)
        }
    }

    kn.sequence = strings.clone(strings.to_string(seq_builder))
}

sort_by_freq :: proc(kn: ^Knuckeotide, seq: string, length: int) {
    n, table := frequency(seq, length, context.temp_allocator)

    entries := make([dynamic]Frequency_Entry, 0, len(table), context.temp_allocator)
    defer delete(entries)

    for key, value in table {

        key_copy := strings.clone(key, context.temp_allocator)
        append(&entries, Frequency_Entry{key_copy, value})
    }

    slice.sort_by(entries[:], proc(a, b: Frequency_Entry) -> bool {
        if a.count == b.count {
            return a.key < b.key  
        }
        return a.count > b.count  
    })

    for entry in entries {
        percent := f64(entry.count * 100) / f64(n)

        upper_builder := strings.builder_make()
        defer strings.builder_destroy(&upper_builder)

        for r in entry.key {
            if r >= 'a' && r <= 'z' {
                strings.write_rune(&upper_builder, r - 32)
            } else {
                strings.write_rune(&upper_builder, r)
            }
        }

        upper := strings.to_string(upper_builder)
        kn.result_str = strings.concatenate({kn.result_str, upper, " ", fmt.tprintf("%.3f", percent), "\n"})
    }

    kn.result_str = strings.concatenate({kn.result_str, "\n"})
}

find_seq :: proc(kn: ^Knuckeotide, seq: string, pattern: string) {
    length := len(pattern)
    _, table := frequency(seq, length, context.temp_allocator)

    pattern_lower_builder := strings.builder_make()
    defer strings.builder_destroy(&pattern_lower_builder)

    for r in pattern {
        if r >= 'A' && r <= 'Z' {
            strings.write_rune(&pattern_lower_builder, r + 32)
        } else {
            strings.write_rune(&pattern_lower_builder, r)
        }
    }

    pattern_lower := strings.to_string(pattern_lower_builder)
    count := 0
    if c, ok := table[pattern_lower]; ok {
        count = c
    }

    pattern_upper_builder := strings.builder_make()
    defer strings.builder_destroy(&pattern_upper_builder)

    for r in pattern {
        if r >= 'a' && r <= 'z' {
            strings.write_rune(&pattern_upper_builder, r - 32)
        } else {
            strings.write_rune(&pattern_upper_builder, r)
        }
    }

    pattern_upper := strings.to_string(pattern_upper_builder)
    kn.result_str = strings.concatenate({kn.result_str, fmt.tprintf("%d", count), "\t", pattern_upper, "\n"})
}

knuckeotide_run :: proc(bench: ^Benchmark, iteration_id: int) {
    kn := cast(^Knuckeotide)bench

    seq_clone := strings.clone(kn.sequence, context.temp_allocator)
    defer delete(seq_clone, context.temp_allocator)

    for i in 1..=2 {
        sort_by_freq(kn, seq_clone, i)
    }

    patterns := [?]string{"ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"}

    for pattern in patterns {
        find_seq(kn, seq_clone, pattern)
    }
}

knuckeotide_checksum :: proc(bench: ^Benchmark) -> u32 {
    kn := cast(^Knuckeotide)bench
    return checksum_string(kn.result_str)
}

knuckeotide_cleanup :: proc(bench: ^Benchmark) {
    kn := cast(^Knuckeotide)bench
    delete(kn.sequence)
    delete(kn.result_str)
}

create_knuckeotide :: proc() -> ^Benchmark {
    kn := new(Knuckeotide)
    kn.name = "CLBG::Knuckeotide"
    kn.vtable = default_vtable()

    kn.vtable.run = knuckeotide_run
    kn.vtable.checksum = knuckeotide_checksum
    kn.vtable.prepare = knuckeotide_prepare
    kn.vtable.cleanup = knuckeotide_cleanup

    return cast(^Benchmark)kn
}