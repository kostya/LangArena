package benchmark

Matmul1T :: struct {
    using base: Benchmark,
    n: int,
    result_val: u32,
}

matmul1t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mt := cast(^Matmul1T)bench

    a := matgen(mt.n)
    defer free_matrix(a)

    b := matgen(mt.n)
    defer free_matrix(b)

    c := matmul_sequential(a, b)
    defer free_matrix(c)

    center_idx := mt.n >> 1
    if center_idx < len(c) && center_idx < len(c[center_idx]) {
        mt.result_val += checksum_f64(c[center_idx][center_idx])
    }
}

matmul1t_checksum :: proc(bench: ^Benchmark) -> u32 {
    mt := cast(^Matmul1T)bench
    return mt.result_val
}

matmul1t_prepare :: proc(bench: ^Benchmark) {
    mt := cast(^Matmul1T)bench
    mt.n = int(config_i64("Matmul::T1", "n"))
}

create_matmul1t :: proc() -> ^Benchmark {
    mt := new(Matmul1T)
    mt.name = "Matmul::T1"
    mt.vtable = default_vtable()

    mt.vtable.run = matmul1t_run
    mt.vtable.checksum = matmul1t_checksum
    mt.vtable.prepare = matmul1t_prepare

    return cast(^Benchmark)mt
}