package benchmark

Matmul4T :: struct {
    using base: Benchmark,
    n: int,
    result_val: u32,
}

matmul4t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mt := cast(^Matmul4T)bench

    a := matgen(mt.n)
    defer free_matrix(a)

    b := matgen(mt.n)
    defer free_matrix(b)

    c := matmul_parallel(a, b, 4)
    defer free_matrix(c)

    center_idx := mt.n >> 1
    if center_idx < len(c) && center_idx < len(c[center_idx]) {
        mt.result_val += checksum_f64(c[center_idx][center_idx])
    }
}

matmul4t_checksum :: proc(bench: ^Benchmark) -> u32 {
    mt := cast(^Matmul4T)bench
    return mt.result_val
}

matmul4t_prepare :: proc(bench: ^Benchmark) {
    mt := cast(^Matmul4T)bench
    mt.n = int(config_i64("Matmul::T4", "n"))
}

create_matmul4t :: proc() -> ^Benchmark {
    mt := new(Matmul4T)
    mt.name = "Matmul::T4"
    mt.vtable = default_vtable()

    mt.vtable.run = matmul4t_run
    mt.vtable.checksum = matmul4t_checksum
    mt.vtable.prepare = matmul4t_prepare

    return cast(^Benchmark)mt
}