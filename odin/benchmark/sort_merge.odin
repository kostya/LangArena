package benchmark

SortMerge :: struct {
    base: SortBenchmark,
}

merge_sort_helper :: proc(arr, temp: []i32, left, right: int) {
    if left >= right {
        return
    }

    mid := (left + right) / 2
    merge_sort_helper(arr, temp, left, mid)
    merge_sort_helper(arr, temp, mid + 1, right)
    merge(arr, temp, left, mid, right)
}

merge :: proc(arr, temp: []i32, left, mid, right: int) {

    copy(temp[left:right+1], arr[left:right+1])

    i := left
    j := mid + 1
    k := left

    for i <= mid && j <= right {
        if temp[i] <= temp[j] {
            arr[k] = temp[i]
            i += 1
        } else {
            arr[k] = temp[j]
            j += 1
        }
        k += 1
    }

    for i <= mid {
        arr[k] = temp[i]
        i += 1
        k += 1
    }
}

sortmerge_test :: proc(bench: ^SortBenchmark) -> []i32 {
    arr := make([]i32, len(bench.data))
    copy(arr, bench.data)

    temp := make([]i32, len(arr))
    defer delete(temp)

    merge_sort_helper(arr, temp, 0, len(arr) - 1)
    return arr
}

create_sortmerge :: proc() -> ^Benchmark {
    sm := new(SortMerge)
    sm.base.name = "SortMerge"

    vtable := new(SortBenchmark_VTable)
    base_vtable := default_vtable()
    vtable.base_vtable = base_vtable^

    vtable.base_vtable.prepare = sortbenchmark_prepare
    vtable.base_vtable.run = sortbenchmark_run
    vtable.base_vtable.checksum = sortbenchmark_checksum
    vtable.base_vtable.cleanup = sortbenchmark_cleanup

    vtable.test = sortmerge_test

    sm.base.vtable = cast(^Benchmark_VTable)vtable

    return cast(^Benchmark)sm
}