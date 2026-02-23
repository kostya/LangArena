package benchmark

import "core:slice"

SortSelf :: struct {
    base: SortBenchmark,
}

sortself_test :: proc(bench: ^SortBenchmark) -> []i32 {
    arr := make([]i32, len(bench.data))
    copy(arr, bench.data)

    slice.sort(arr[:])
    return arr
}

create_sortself :: proc() -> ^Benchmark {
    ss := new(SortSelf)
    ss.base.name = "Sort::Self"

    vtable := new(SortBenchmark_VTable)
    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = sortbenchmark_prepare
    vtable.base_vtable.run = sortbenchmark_run
    vtable.base_vtable.checksum = sortbenchmark_checksum
    vtable.base_vtable.cleanup = sortbenchmark_cleanup

    vtable.test = sortself_test

    ss.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)ss
}