package benchmark

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