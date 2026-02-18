package benchmark

import "core:math"

Spectralnorm :: struct {
    using base: Benchmark,
    size_val: int,
    u: []f64,
    v: []f64,
    temp: []f64,  
}

eval_A :: proc(i, j: int) -> f64 {
    return 1.0 / (f64(i + j) * f64(i + j + 1.0) / 2.0 + f64(i) + 1.0)
}

eval_A_times_u :: proc(u: []f64) -> []f64 {
    v := make([]f64, len(u))

    for i in 0..<len(u) {
        sum: f64 = 0.0
        for j in 0..<len(u) {
            sum += eval_A(i, j) * u[j]
        }
        v[i] = sum
    }
    return v
}

eval_At_times_u :: proc(u: []f64) -> []f64 {
    v := make([]f64, len(u))

    for i in 0..<len(u) {
        sum: f64 = 0.0
        for j in 0..<len(u) {
            sum += eval_A(j, i) * u[j]
        }
        v[i] = sum
    }
    return v
}

eval_AtA_times_u :: proc(u: []f64) -> []f64 {
    temp := eval_A_times_u(u)  
    defer delete(temp)         
    return eval_At_times_u(temp)  
}

spectralnorm_prepare :: proc(bench: ^Benchmark) {
    sn := cast(^Spectralnorm)bench
    sn.size_val = int(config_i64("Spectralnorm", "size"))

    sn.u = make([]f64, sn.size_val)
    sn.v = make([]f64, sn.size_val)

    for i in 0..<sn.size_val {
        sn.u[i] = 1.0
        sn.v[i] = 1.0
    }
}

spectralnorm_run :: proc(bench: ^Benchmark, iteration_id: int) {
    sn := cast(^Spectralnorm)bench

    new_v := eval_AtA_times_u(sn.u)
    delete(sn.v)        
    sn.v = new_v        

    new_u := eval_AtA_times_u(sn.v)
    delete(sn.u)        
    sn.u = new_u        
}

spectralnorm_checksum :: proc(bench: ^Benchmark) -> u32 {
    sn := cast(^Spectralnorm)bench

    vBv: f64 = 0.0
    vv: f64 = 0.0

    for i in 0..<sn.size_val {
        vBv += sn.u[i] * sn.v[i]
        vv += sn.v[i] * sn.v[i]
    }

    return checksum_f64(math.sqrt(vBv / vv))
}

spectralnorm_cleanup :: proc(bench: ^Benchmark) {
    sn := cast(^Spectralnorm)bench

    if sn.u != nil do delete(sn.u)
    if sn.v != nil do delete(sn.v)
}

create_spectralnorm :: proc() -> ^Benchmark {
    sn := new(Spectralnorm)
    sn.name = "Spectralnorm"
    sn.vtable = default_vtable()

    sn.vtable.run = spectralnorm_run
    sn.vtable.checksum = spectralnorm_checksum
    sn.vtable.prepare = spectralnorm_prepare
    sn.vtable.cleanup = spectralnorm_cleanup

    return cast(^Benchmark)sn
}