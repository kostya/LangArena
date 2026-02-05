using ..BenchmarkFramework

abstract type AbstractSortBenchmark <: AbstractBenchmark end

mutable struct SortBenchmark <: AbstractSortBenchmark
    size::Int64
    data::Vector{Int32}
    result::UInt32

    function SortBenchmark()
        size_val = Helper.config_i64("SortBenchmark", "size")
        new(size_val, Int32[], UInt32(0))
    end
end

name(b::SortBenchmark)::String = "SortBenchmark"

function prepare(b::SortBenchmark)
    empty!(b.data)
    for _ in 1:b.size
        push!(b.data, Helper.next_int(1_000_000))
    end
end

function run(b::SortBenchmark, iteration_id::Int64)

    error("Abstract method 'test' not implemented")
end

function test(b::SortBenchmark)::Vector{Int32}

    error("Abstract method 'test' not implemented")
end

function checksum(b::SortBenchmark)::UInt32
    return b.result
end

mutable struct SortQuick <: AbstractSortBenchmark
    size::Int64
    data::Vector{Int32}
    result::UInt32

    function SortQuick()
        size_val = Helper.config_i64("SortQuick", "size")
        new(size_val, Int32[], UInt32(0))
    end
end

name(b::SortQuick)::String = "SortQuick"

function prepare(b::SortQuick)
    empty!(b.data)
    for _ in 1:b.size
        push!(b.data, Helper.next_int(1_000_000))
    end
end

function quick_sort!(arr::Vector{Int32}, low::Int, high::Int)
    if low >= high
        return
    end

    pivot = arr[(low + high) ÷ 2]
    i = low
    j = high

    while i <= j
        while arr[i] < pivot
            i += 1
        end
        while arr[j] > pivot
            j -= 1
        end
        if i <= j
            arr[i], arr[j] = arr[j], arr[i]
            i += 1
            j -= 1
        end
    end

    quick_sort!(arr, low, j)
    quick_sort!(arr, i, high)
end

function test(b::SortQuick)::Vector{Int32}
    arr = copy(b.data)
    if length(arr) > 0
        quick_sort!(arr, 1, length(arr))  
    end
    return arr
end

function run(b::SortQuick, iteration_id::Int64)

    if length(b.data) > 0
        idx = Helper.next_int(length(b.data)) + 1  
        b.result = (b.result + UInt32(b.data[idx])) & 0xffffffff
    end

    sorted_arr = test(b)
    if length(sorted_arr) > 0
        idx = Helper.next_int(length(sorted_arr)) + 1  
        b.result = (b.result + UInt32(sorted_arr[idx])) & 0xffffffff
    end
end

mutable struct SortMerge <: AbstractSortBenchmark
    size::Int64
    data::Vector{Int32}
    result::UInt32

    function SortMerge()
        size_val = Helper.config_i64("SortMerge", "size")
        new(size_val, Int32[], UInt32(0))
    end
end

name(b::SortMerge)::String = "SortMerge"

function prepare(b::SortMerge)
    empty!(b.data)
    for _ in 1:b.size
        push!(b.data, Helper.next_int(1_000_000))
    end
end

function merge_sort!(arr::Vector{Int32})
    if length(arr) <= 1
        return arr
    end

    temp = similar(arr)
    merge_sort_helper!(arr, temp, 1, length(arr))  
    return arr
end

function merge_sort_helper!(arr::Vector{Int32}, temp::Vector{Int32}, left::Int, right::Int)
    if left >= right
        return
    end

    mid = (left + right) ÷ 2
    merge_sort_helper!(arr, temp, left, mid)
    merge_sort_helper!(arr, temp, mid + 1, right)
    merge!(arr, temp, left, mid, right)
end

function merge!(arr::Vector{Int32}, temp::Vector{Int32}, left::Int, mid::Int, right::Int)

    for i in left:right
        temp[i] = arr[i]
    end

    i = left      
    j = mid + 1   
    k = left      

    while i <= mid && j <= right
        if temp[i] <= temp[j]
            arr[k] = temp[i]
            i += 1
        else
            arr[k] = temp[j]
            j += 1
        end
        k += 1
    end

    while i <= mid
        arr[k] = temp[i]
        i += 1
        k += 1
    end
end

function test(b::SortMerge)::Vector{Int32}
    arr = copy(b.data)
    if length(arr) > 0
        merge_sort!(arr)
    end
    return arr
end

function run(b::SortMerge, iteration_id::Int64)

    if length(b.data) > 0
        idx = Helper.next_int(length(b.data)) + 1  
        b.result = (b.result + UInt32(b.data[idx])) & 0xffffffff
    end

    sorted_arr = test(b)
    if length(sorted_arr) > 0
        idx = Helper.next_int(length(sorted_arr)) + 1  
        b.result = (b.result + UInt32(sorted_arr[idx])) & 0xffffffff
    end
end

mutable struct SortSelf <: AbstractSortBenchmark
    size::Int64
    data::Vector{Int32}
    result::UInt32

    function SortSelf()
        size_val = Helper.config_i64("SortSelf", "size")
        new(size_val, Int32[], UInt32(0))
    end
end

name(b::SortSelf)::String = "SortSelf"

function prepare(b::SortSelf)
    empty!(b.data)
    for _ in 1:b.size
        push!(b.data, Helper.next_int(1_000_000))
    end
end

function test(b::SortSelf)::Vector{Int32}
    arr = copy(b.data)
    sort!(arr)
    return arr
end

function run(b::SortSelf, iteration_id::Int64)

    if length(b.data) > 0
        idx = Helper.next_int(length(b.data)) + 1  
        b.result = (b.result + UInt32(b.data[idx])) & 0xffffffff
    end

    sorted_arr = test(b)
    if length(sorted_arr) > 0
        idx = Helper.next_int(length(sorted_arr)) + 1  
        b.result = (b.result + UInt32(sorted_arr[idx])) & 0xffffffff
    end
end

function checksum(b::AbstractSortBenchmark)::UInt32
    return b.result
end