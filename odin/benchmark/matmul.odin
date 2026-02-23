package benchmark

import "core:thread"
import "core:math"

matgen :: proc(n: int) -> [][]f64 {
    tmp := 1.0 / f64(n) / f64(n)

    a := make([][]f64, n)
    for i in 0..<n {
        a[i] = make([]f64, n)
        for j in 0..<n {
            a[i][j] = tmp * f64(i - j) * f64(i + j)
        }
    }

    return a
}

free_matrix :: proc(mat: [][]f64) {
    for row in mat {
        delete(row)
    }
    delete(mat)
}

transpose :: proc(a: [][]f64) -> [][]f64 {
    m := len(a)
    n := len(a[0])

    b := make([][]f64, n)
    for i in 0..<n {
        b[i] = make([]f64, m)
        for j in 0..<m {
            b[i][j] = a[j][i]
        }
    }

    return b
}

matmul_sequential :: proc(a, b: [][]f64) -> [][]f64 {
    m := len(a)
    n := len(a[0])
    p := len(b[0])

    b_t := transpose(b)
    defer free_matrix(b_t)

    c := make([][]f64, m)
    for i in 0..<m {
        c[i] = make([]f64, p)
    }

    for i in 0..<m {
        ai := a[i]
        ci := c[i]

        for j in 0..<p {
            sum: f64 = 0.0
            b_tj := b_t[j]

            for k in 0..<n {
                sum += ai[k] * b_tj[k]
            }

            ci[j] = sum
        }
    }

    return c
}

Thread_Data :: struct {
    start_row: int,
    end_row:   int,
    a:         [][]f64,
    b_t:       [][]f64,
    c:         [][]f64,
    n:         int,
    p:         int,
}

thread_proc :: proc(t: ^thread.Thread) {
    data := cast(^Thread_Data)t.data

    n := data.n
    p := data.p

    for i in data.start_row..<data.end_row {
        ai := data.a[i]
        ci := data.c[i]

        for j in 0..<p {
            sum: f64 = 0.0
            b_tj := data.b_t[j]

            for k in 0..<n {
                sum += ai[k] * b_tj[k]
            }

            ci[j] = sum
        }
    }
}

matmul_parallel :: proc(a, b: [][]f64, num_threads: int) -> [][]f64 {
    m := len(a)
    n := len(a[0])
    p := len(b[0])

    b_t := transpose(b)
    defer free_matrix(b_t)

    c := make([][]f64, m)
    for i in 0..<m {
        c[i] = make([]f64, p)
    }

    threads := make([]^thread.Thread, num_threads)
    defer delete(threads)
    thread_data := make([]Thread_Data, num_threads)
    defer delete(thread_data)

    rows_per_thread := m / num_threads
    extra_rows := m % num_threads

    current_row := 0

    for t in 0..<num_threads {
        start_row := current_row
        end_row := start_row + rows_per_thread

        if t < extra_rows {
            end_row += 1
        }

        thread_data[t] = Thread_Data{
            start_row = start_row,
            end_row   = end_row,
            a         = a,
            b_t       = b_t,
            c         = c,
            n         = n,
            p         = p,
        }

        threads[t] = thread.create(thread_proc)
        threads[t].data = &thread_data[t]
        thread.start(threads[t])

        current_row = end_row
    }

    for t in 0..<num_threads {
        thread.join(threads[t])
        thread.destroy(threads[t])
    }

    return c
}

MatmulBase :: struct {
    using base: Benchmark,
    n: int,
    result_val: u32,
    a: [][]f64,
    b: [][]f64,
    num_threads: int,
}

matmulbase_prepare :: proc(bench: ^Benchmark) {
    mb := cast(^MatmulBase)bench
    mb.n = int(config_i64(mb.name, "n"))
    mb.a = matgen(mb.n)
    mb.b = matgen(mb.n)
    mb.result_val = 0
}

matmulbase_checksum :: proc(bench: ^Benchmark) -> u32 {
    mb := cast(^MatmulBase)bench
    return mb.result_val
}

matmulbase_cleanup :: proc(bench: ^Benchmark) {
    mb := cast(^MatmulBase)bench
    if mb.a != nil do free_matrix(mb.a)
    if mb.b != nil do free_matrix(mb.b)
}

create_matmulbase :: proc(name: string, num_threads: int) -> ^Benchmark {
    mb := new(MatmulBase)
    mb.name = name
    mb.num_threads = num_threads
    mb.vtable = default_vtable()

    mb.vtable.prepare = matmulbase_prepare
    mb.vtable.checksum = matmulbase_checksum
    mb.vtable.cleanup = matmulbase_cleanup

    return cast(^Benchmark)mb
}

matmul1t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mb := cast(^MatmulBase)bench

    c := matmul_sequential(mb.a, mb.b)
    defer free_matrix(c)

    center_idx := mb.n >> 1
    mb.result_val += checksum_f64(c[center_idx][center_idx])
}

create_matmul1t :: proc() -> ^Benchmark {
    bench := create_matmulbase("Matmul::Single", 1)
    mb := cast(^MatmulBase)bench
    mb.vtable.run = matmul1t_run
    return bench
}

matmul4t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mb := cast(^MatmulBase)bench

    c := matmul_parallel(mb.a, mb.b, 4)
    defer free_matrix(c)

    center_idx := mb.n >> 1
    mb.result_val += checksum_f64(c[center_idx][center_idx])
}

create_matmul4t :: proc() -> ^Benchmark {
    bench := create_matmulbase("Matmul::T4", 4)
    mb := cast(^MatmulBase)bench
    mb.vtable.run = matmul4t_run
    return bench
}

matmul8t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mb := cast(^MatmulBase)bench

    c := matmul_parallel(mb.a, mb.b, 8)
    defer free_matrix(c)

    center_idx := mb.n >> 1
    mb.result_val += checksum_f64(c[center_idx][center_idx])
}

create_matmul8t :: proc() -> ^Benchmark {
    bench := create_matmulbase("Matmul::T8", 8)
    mb := cast(^MatmulBase)bench
    mb.vtable.run = matmul8t_run
    return bench
}

matmul16t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mb := cast(^MatmulBase)bench

    c := matmul_parallel(mb.a, mb.b, 16)
    defer free_matrix(c)

    center_idx := mb.n >> 1
    mb.result_val += checksum_f64(c[center_idx][center_idx])
}

create_matmul16t :: proc() -> ^Benchmark {
    bench := create_matmulbase("Matmul::T16", 16)
    mb := cast(^MatmulBase)bench
    mb.vtable.run = matmul16t_run
    return bench
}