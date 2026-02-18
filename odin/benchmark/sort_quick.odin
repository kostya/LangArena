package benchmark

import "core:slice"

SortQuick :: struct {
    base: SortBenchmark,
}

quick_sort :: proc(arr: []i32, low, high: int) {
    if low >= high {
        return
    }

    pivot := arr[(low + high) / 2]
    i := low
    j := high

    for i <= j {
        for arr[i] < pivot {
            i += 1
        }
        for arr[j] > pivot {
            j -= 1
        }

        if i <= j {
            arr[i], arr[j] = arr[j], arr[i]
            i += 1
            j -= 1
        }
    }

    quick_sort(arr, low, j)
    quick_sort(arr, i, high)
}

sortquick_test :: proc(bench: ^SortBenchmark) -> []i32 {
    arr := make([]i32, len(bench.data))
    copy(arr, bench.data)

    quick_sort(arr, 0, len(arr) - 1)
    return arr
}

create_sortquick :: proc() -> ^Benchmark {
    sq := new(SortQuick)
    sq.base.name = "SortQuick"

    vtable := new(SortBenchmark_VTable)

    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = sortbenchmark_prepare
    vtable.base_vtable.run = sortbenchmark_run
    vtable.base_vtable.checksum = sortbenchmark_checksum
    vtable.base_vtable.cleanup = sortbenchmark_cleanup

    vtable.test = sortquick_test

    sq.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)sq
}