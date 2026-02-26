package benchmark

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:container/small_array"
import "core:math"

StringPair :: struct {
    s1: string,
    s2: string,
}

generate_pair_strings :: proc(n: int, m: int) -> []StringPair {
    pairs := make([]StringPair, n)
    chars := "abcdefghij"

    for i in 0..<n {
        len1 := next_int(m) + 4
        len2 := next_int(m) + 4

        str1_buf := make([]byte, len1)
        str2_buf := make([]byte, len2)

        for j in 0..<len1 {
            str1_buf[j] = chars[next_int(10)]
        }
        for j in 0..<len2 {
            str2_buf[j] = chars[next_int(10)]
        }

        pairs[i] = StringPair{string(str1_buf), string(str2_buf)}
    }

    return pairs
}

Jaro :: struct {
    using base: Benchmark,
    count: int,
    size: int,
    pairs: []StringPair,
    result_val: u32,
}

jaro_run :: proc(bench: ^Benchmark, iteration_id: int) {
    j := cast(^Jaro)bench

    for pair in j.pairs {
        j.result_val += u32(jaro_calc(pair.s1, pair.s2) * 1000)
    }
}

jaro_calc :: proc(s1: string, s2: string) -> f64 {

    bytes1 := transmute([]byte)s1
    bytes2 := transmute([]byte)s2

    len1 := len(bytes1)
    len2 := len(bytes2)

    if len1 == 0 || len2 == 0 {
        return 0.0
    }

    match_dist := max(len1, len2) / 2 - 1
    if match_dist < 0 {
        match_dist = 0
    }

    s1_matches := make([]bool, len1)
    defer delete(s1_matches)
    s2_matches := make([]bool, len2)
    defer delete(s2_matches)

    matches := 0
    for i in 0..<len1 {
        start := max(0, i - match_dist)
        end := min(len2 - 1, i + match_dist)

        for j in start..=end {
            if !s2_matches[j] && bytes1[i] == bytes2[j] {
                s1_matches[i] = true
                s2_matches[j] = true
                matches += 1
                break
            }
        }
    }

    if matches == 0 {
        return 0.0
    }

    transpositions := 0
    k := 0
    for i in 0..<len1 {
        if s1_matches[i] {
            for k < len2 && !s2_matches[k] {
                k += 1
            }
            if k < len2 {
                if bytes1[i] != bytes2[k] {
                    transpositions += 1
                }
                k += 1
            }
        }
    }
    transpositions /= 2

    m := f64(matches)
    return (m/f64(len1) + m/f64(len2) + (m - f64(transpositions))/m) / 3.0
}

jaro_checksum :: proc(bench: ^Benchmark) -> u32 {
    j := cast(^Jaro)bench
    return j.result_val
}

jaro_prepare :: proc(bench: ^Benchmark) {
    j := cast(^Jaro)bench

    j.count = int(config_i64("Distance::Jaro", "count"))
    j.size = int(config_i64("Distance::Jaro", "size"))
    j.pairs = generate_pair_strings(j.count, j.size)
    j.result_val = 0
}

jaro_cleanup :: proc(bench: ^Benchmark) {
    j := cast(^Jaro)bench

    for pair in j.pairs {
        delete(pair.s1)
        delete(pair.s2)
    }
    delete(j.pairs)
}

create_jaro :: proc() -> ^Benchmark {
    bench := new(Jaro)
    bench.name = "Distance::Jaro"
    bench.vtable = default_vtable()

    bench.vtable.run = jaro_run
    bench.vtable.checksum = jaro_checksum
    bench.vtable.prepare = jaro_prepare
    bench.vtable.cleanup = jaro_cleanup

    return cast(^Benchmark)bench
}

NGram :: struct {
    using base: Benchmark,
    count: int,
    size: int,
    pairs: []StringPair,
    result_val: u32,
}

ngram_run :: proc(bench: ^Benchmark, iteration_id: int) {
    ng := cast(^NGram)bench

    for pair in ng.pairs {
        ng.result_val += u32(ngram_calc(ng, pair.s1, pair.s2) * 1000)
    }
}

ngram_calc :: proc(ng: ^NGram, s1: string, s2: string) -> f64 {
    bytes1 := transmute([]byte)s1
    bytes2 := transmute([]byte)s2
    len1 := len(bytes1)
    len2 := len(bytes2)

    if len1 < 4 || len2 < 4 {
        return 0.0
    }

    grams1 := make(map[u32]int)
    defer delete(grams1)

    for i in 0..=(len1 - 4) {
        gram := (u32(bytes1[i]) << 24) |
                (u32(bytes1[i+1]) << 16) |
                (u32(bytes1[i+2]) << 8) |
                 u32(bytes1[i+3])

        if gram in grams1 {
            grams1[gram] += 1
        } else {
            grams1[gram] = 1
        }
    }

    grams2 := make(map[u32]int)
    defer delete(grams2)
    intersection := 0

    for i in 0..=(len2 - 4) {
        gram := (u32(bytes2[i]) << 24) |
                (u32(bytes2[i+1]) << 16) |
                (u32(bytes2[i+2]) << 8) |
                 u32(bytes2[i+3])

        if gram in grams2 {
            grams2[gram] += 1
        } else {
            grams2[gram] = 1
        }

        if gram in grams1 {
            if grams2[gram] <= grams1[gram] {
                intersection += 1
            }
        }
    }

    total := len(grams1) + len(grams2)
    return total > 0 ? f64(intersection) / f64(total) : 0.0
}
ngram_checksum :: proc(bench: ^Benchmark) -> u32 {
    ng := cast(^NGram)bench
    return ng.result_val
}

ngram_prepare :: proc(bench: ^Benchmark) {
    ng := cast(^NGram)bench

    ng.count = int(config_i64("Distance::NGram", "count"))
    ng.size = int(config_i64("Distance::NGram", "size"))
    ng.pairs = generate_pair_strings(ng.count, ng.size)
    ng.result_val = 0
}

ngram_cleanup :: proc(bench: ^Benchmark) {
    ng := cast(^NGram)bench

    for pair in ng.pairs {
        delete(pair.s1)
        delete(pair.s2)
    }
    delete(ng.pairs)
}

create_ngram :: proc() -> ^Benchmark {
    bench := new(NGram)
    bench.name = "Distance::NGram"
    bench.vtable = default_vtable()

    bench.vtable.run = ngram_run
    bench.vtable.checksum = ngram_checksum
    bench.vtable.prepare = ngram_prepare
    bench.vtable.cleanup = ngram_cleanup

    return cast(^Benchmark)bench
}