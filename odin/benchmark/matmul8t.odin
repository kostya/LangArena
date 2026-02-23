package benchmark

Matmul8T :: struct {
    using base: Benchmark,
    n: int,
    result_val: u32,
}

matmul8t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mt := cast(^Matmul8T)bench

    a := matgen(mt.n)
    defer free_matrix(a)

    b := matgen(mt.n)
    defer free_matrix(b)

    c := matmul_parallel(a, b, 8)
    defer free_matrix(c)

    center_idx := mt.n >> 1
    if center_idx < len(c) && center_idx < len(c[center_idx]) {
        mt.result_val += checksum_f64(c[center_idx][center_idx])
    }
}

matmul8t_checksum :: proc(bench: ^Benchmark) -> u32 {
    mt := cast(^Matmul8T)bench
    return mt.result_val
}

matmul8t_prepare :: proc(bench: ^Benchmark) {
    mt := cast(^Matmul8T)bench
    mt.n = int(config_i64("Matmul::T8", "n"))
}

create_matmul8t :: proc() -> ^Benchmark {
    mt := new(Matmul8T)
    mt.name = "Matmul::T8"
    mt.vtable = default_vtable()

    mt.vtable.run = matmul8t_run
    mt.vtable.checksum = matmul8t_checksum
    mt.vtable.prepare = matmul8t_prepare

    return cast(^Benchmark)mt
}