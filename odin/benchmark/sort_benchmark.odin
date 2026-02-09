package benchmark

import "core:slice"

SortBenchmark :: struct {
    using base: Benchmark,
    data: []i32,
    size_val: int,
    result_val: u32,
}

SortBenchmark_VTable :: struct {
    using base_vtable: Benchmark_VTable,
    test: proc(bench: ^SortBenchmark) -> []i32,
}

sortbenchmark_prepare :: proc(bench: ^Benchmark) {
    sb := cast(^SortBenchmark)bench

    if sb.size_val == 0 {
        sb.size_val = int(config_i64(sb.name, "size"))
        sb.data = make([]i32, sb.size_val)

        for i in 0..<sb.size_val {
            sb.data[i] = i32(next_int(1_000_000))
        }
    }
}

sortbenchmark_run :: proc(bench: ^Benchmark, iteration_id: int) {
    sb := cast(^SortBenchmark)bench
    vtable := cast(^SortBenchmark_VTable)bench.vtable

    sb.result_val += u32(sb.data[next_int(sb.size_val)])

    sorted := vtable.test(sb)
    defer delete(sorted)

    sb.result_val += u32(sorted[next_int(sb.size_val)])
}

sortbenchmark_checksum :: proc(bench: ^Benchmark) -> u32 {
    sb := cast(^SortBenchmark)bench
    return sb.result_val
}

sortbenchmark_cleanup :: proc(bench: ^Benchmark) {
    sb := cast(^SortBenchmark)bench
    delete(sb.data)
}