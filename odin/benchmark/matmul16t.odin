package benchmark

Matmul16T :: struct {
    using base: Benchmark,
    n: int,
    result_val: u32,
}

matmul16t_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mt := cast(^Matmul16T)bench

    a := matgen(mt.n)
    defer free_matrix(a)

    b := matgen(mt.n)
    defer free_matrix(b)

    c := matmul_parallel(a, b, 16)
    defer free_matrix(c)

    center_idx := mt.n >> 1
    if center_idx < len(c) && center_idx < len(c[center_idx]) {
        mt.result_val += checksum_f64(c[center_idx][center_idx])
    }
}

matmul16t_checksum :: proc(bench: ^Benchmark) -> u32 {
    mt := cast(^Matmul16T)bench
    return mt.result_val
}

matmul16t_prepare :: proc(bench: ^Benchmark) {
    mt := cast(^Matmul16T)bench
    mt.n = int(config_i64("Matmul::T16", "n"))
}

create_matmul16t :: proc() -> ^Benchmark {
    mt := new(Matmul16T)
    mt.name = "Matmul::T16"
    mt.vtable = default_vtable()

    mt.vtable.run = matmul16t_run
    mt.vtable.checksum = matmul16t_checksum
    mt.vtable.prepare = matmul16t_prepare

    return cast(^Benchmark)mt
}