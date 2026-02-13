package benchmark

import "core:strings"
import "core:fmt"

Gene :: struct {
    c:    rune,
    prob: f64,
}

LINE_LENGTH :: 60

Fasta :: struct {
    using base: Benchmark,
    n: int,
    result_builder: strings.Builder,
}

select_random :: proc(genelist: []Gene) -> rune {
    r := next_float()
    if r < genelist[0].prob {
        return genelist[0].c
    }

    lo := 0
    hi := len(genelist) - 1

    for hi > lo + 1 {
        i := (hi + lo) / 2
        if r < genelist[i].prob {
            hi = i
        } else {
            lo = i
        }
    }
    return genelist[hi].c
}

make_random_fasta :: proc(fasta: ^Fasta, id, desc: string, genelist: []Gene, n_iter: int) {
    strings.write_string(&fasta.result_builder, ">")
    strings.write_string(&fasta.result_builder, id)
    strings.write_string(&fasta.result_builder, " ")
    strings.write_string(&fasta.result_builder, desc)
    strings.write_string(&fasta.result_builder, "\n")

    todo := n_iter

    for todo > 0 {
        m := todo if todo < LINE_LENGTH else LINE_LENGTH
        for i in 0..<m {
            strings.write_rune(&fasta.result_builder, select_random(genelist))
        }
        strings.write_string(&fasta.result_builder, "\n")
        todo -= LINE_LENGTH
    }
}

make_repeat_fasta :: proc(fasta: ^Fasta, id, desc, s: string, n_iter: int) {
    strings.write_string(&fasta.result_builder, ">")
    strings.write_string(&fasta.result_builder, id)
    strings.write_string(&fasta.result_builder, " ")
    strings.write_string(&fasta.result_builder, desc)
    strings.write_string(&fasta.result_builder, "\n")

    todo := n_iter
    k := 0
    kn := len(s)

    for todo > 0 {
        m := todo if todo < LINE_LENGTH else LINE_LENGTH

        for m >= kn - k {
            strings.write_string(&fasta.result_builder, s[k:])
            m -= kn - k
            k = 0
        }

        strings.write_string(&fasta.result_builder, s[k:k + m])
        strings.write_string(&fasta.result_builder, "\n")
        k += m
        todo -= LINE_LENGTH
    }
}

fasta_run :: proc(bench: ^Benchmark, iteration_id: int) {
    fasta := cast(^Fasta)bench

    IUB := []Gene{
        {'a', 0.27}, {'c', 0.39}, {'g', 0.51}, {'t', 0.78}, {'B', 0.8}, {'D', 0.8200000000000001},
        {'H', 0.8400000000000001}, {'K', 0.8600000000000001}, {'M', 0.8800000000000001},
        {'N', 0.9000000000000001}, {'R', 0.9200000000000002}, {'S', 0.9400000000000002},
        {'V', 0.9600000000000002}, {'W', 0.9800000000000002}, {'Y', 1.0000000000000002},
    }

    HOMO := []Gene{
        {'a', 0.302954942668}, {'c', 0.5009432431601}, {'g', 0.6984905497992}, {'t', 1.0},
    }

    ALU := "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

    make_repeat_fasta(fasta, "ONE", "Homo sapiens alu", ALU, fasta.n * 2)
    make_random_fasta(fasta, "TWO", "IUB ambiguity codes", IUB, fasta.n * 3)
    make_random_fasta(fasta, "THREE", "Homo sapiens frequency", HOMO, fasta.n * 5)
}

fasta_checksum :: proc(bench: ^Benchmark) -> u32 {
    fasta := cast(^Fasta)bench
    result := strings.to_string(fasta.result_builder)
    return checksum_string(result)
}

fasta_prepare :: proc(bench: ^Benchmark) {
    fasta := cast(^Fasta)bench
    strings.builder_init(&fasta.result_builder)
}

fasta_cleanup :: proc(bench: ^Benchmark) {
    fasta := cast(^Fasta)bench
    strings.builder_destroy(&fasta.result_builder)
}

create_fasta :: proc() -> ^Benchmark {
    fasta := new(Fasta)
    fasta.name = "Fasta"
    fasta.vtable = default_vtable()

    fasta.vtable.run = fasta_run
    fasta.vtable.checksum = fasta_checksum
    fasta.vtable.prepare = fasta_prepare
    fasta.vtable.cleanup = fasta_cleanup

    fasta.n = int(config_i64("Fasta", "n"))

    return cast(^Benchmark)fasta
}

fasta_get_result :: proc(bench: ^Benchmark) -> string {
    fasta := cast(^Fasta)bench

    builder_len := strings.builder_len(fasta.result_builder)

    if builder_len == 0 {
        return ""
    }

    buf_slice := fasta.result_builder.buf[:builder_len]
    result := strings.clone(string(buf_slice))        
    return result
}