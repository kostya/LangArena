package benchmark

import "core:thread"

Thread_Data :: struct {
    start_row: int,
    end_row:   int,
    a:         [][]f64,
    b_t:       [][]f64,
    c:         [][]f64,
}

thread_proc :: proc(t: ^thread.Thread) {
    data := cast(^Thread_Data)t.data

    m := len(data.a)
    n := len(data.a[0])
    p := len(data.b_t)

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
    thread_data := make([]Thread_Data, num_threads)

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
        }

        threads[t] = thread.create(thread_proc)
        threads[t].data = &thread_data[t]
        thread.start(threads[t])

        current_row = end_row
    }

    for t in 0..<num_threads {
        thread.join(threads[t])
        free(threads[t])
    }

    delete(threads)
    delete(thread_data)

    return c
}