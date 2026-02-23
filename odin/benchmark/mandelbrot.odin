package benchmark

import "core:fmt"

ITER :: 50
LIMIT :: 2.0

Mandelbrot :: struct {
    using base: Benchmark,
    w, h: int,
    result_bytes: [dynamic]u8,
}

mandelbrot_run :: proc(bench: ^Benchmark, iteration_id: int) {
    mb := cast(^Mandelbrot)bench

    header := fmt.tprintf("P4\n%d %d\n", mb.w, mb.h)

    for c in header {
        append(&mb.result_bytes, u8(c))
    }

    bit_num := 0
    byte_acc: u8 = 0

    for y in 0..<mb.h {
        for x in 0..<mb.w {
            cr := 2.0 * f64(x) / f64(mb.w) - 1.5
            ci := 2.0 * f64(y) / f64(mb.h) - 1.0

            zr, zi, tr, ti: f64
            i := 0

            for i < ITER && tr + ti <= LIMIT * LIMIT {
                zi = 2.0 * zr * zi + ci
                zr = tr - ti + cr
                tr = zr * zr
                ti = zi * zi
                i += 1
            }

            byte_acc <<= 1
            if tr + ti <= LIMIT * LIMIT {
                byte_acc |= 0x01
            }
            bit_num += 1

            if bit_num == 8 {
                append(&mb.result_bytes, byte_acc)
                byte_acc = 0
                bit_num = 0
            } else if x == mb.w - 1 {

                shift_amount := u32(8 - (mb.w % 8))
                byte_acc <<= shift_amount
                append(&mb.result_bytes, byte_acc)
                byte_acc = 0
                bit_num = 0
            }
        }
    }
}

mandelbrot_checksum :: proc(bench: ^Benchmark) -> u32 {
    mb := cast(^Mandelbrot)bench
    return checksum_bytes(mb.result_bytes[:])
}

mandelbrot_prepare :: proc(bench: ^Benchmark) {
    mb := cast(^Mandelbrot)bench
    mb.w = int(config_i64("CLBG::Mandelbrot", "w"))
    mb.h = int(config_i64("CLBG::Mandelbrot", "h"))
    mb.result_bytes = make([dynamic]u8)
}

mandelbrot_cleanup :: proc(bench: ^Benchmark) {
    mb := cast(^Mandelbrot)bench
    delete(mb.result_bytes)
}

create_mandelbrot :: proc() -> ^Benchmark {
    mb := new(Mandelbrot)
    mb.name = "CLBG::Mandelbrot"
    mb.vtable = default_vtable()

    mb.vtable.run = mandelbrot_run
    mb.vtable.checksum = mandelbrot_checksum
    mb.vtable.prepare = mandelbrot_prepare
    mb.vtable.cleanup = mandelbrot_cleanup

    return cast(^Benchmark)mb
}