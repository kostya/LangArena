package benchmark

import "core:fmt"
import "core:math/big"
import "core:strconv"
import "core:strings"
import "core:mem"

Pidigits :: struct {
    using base: Benchmark,
    nn: int,
    result: strings.Builder,
}

pidigits_run :: proc(bench: ^Benchmark, iteration_id: int) {
    pd := cast(^Pidigits)bench

    ns, a, n, d, ten, three, t, temp, u, d_t, a_minus_dt, ns_temp: big.Int
    defer {
        big.destroy(&ns)
        big.destroy(&a)
        big.destroy(&n)
        big.destroy(&d)
        big.destroy(&ten)
        big.destroy(&three)
        big.destroy(&t)
        big.destroy(&temp)
        big.destroy(&u)
        big.destroy(&d_t)
        big.destroy(&a_minus_dt)
        big.destroy(&ns_temp)
    }

    big.set(&ten, 10)
    big.set(&three, 3)
    big.set(&n, 1)
    big.set(&d, 1)

    i, k, k1: int
    k1 = 1

    for {
        k += 1

        temp_two: big.Int
        big.set(&temp_two, 2)
        big.mul(&t, &n, &temp_two)
        big.destroy(&temp_two)

        temp_k: big.Int
        big.set(&temp_k, i64(k))
        big.mul(&n, &n, &temp_k)
        big.destroy(&temp_k)

        k1 += 2

        big.add(&temp, &a, &t)
        temp_k1: big.Int
        big.set(&temp_k1, i64(k1))
        big.mul(&a, &temp, &temp_k1)
        big.destroy(&temp_k1)

        temp_k1_2: big.Int
        big.set(&temp_k1_2, i64(k1))
        big.mul(&d, &d, &temp_k1_2)
        big.destroy(&temp_k1_2)

        cmp, cmp_err := big.cmp(&a, &n)
        if cmp_err == nil && cmp >= 0 {  

            big.mul(&temp, &n, &three)
            big.add(&temp, &temp, &a)

            big.div(&t, &temp, &d)

            big.mul(&d_t, &t, &d)
            big.sub(&u, &temp, &d_t)

            big.add(&u, &u, &n)

            cmp2, cmp_err2 := big.cmp(&d, &u)
            if cmp_err2 == nil && cmp2 > 0 {
                big.mul(&ns_temp, &ns, &ten)
                big.add(&ns, &ns_temp, &t)

                i += 1

                if i % 10 == 0 {
                    ns_str, err := big.itoa(&ns, 10)
                    defer delete(ns_str)

                    ns_u64: u64 = 0
                    if err == nil && len(ns_str) > 0 {

                        if len(ns_str) >= 10 {

                            truncated := ns_str[len(ns_str)-10:]
                            ns_u64, _ = strconv.parse_u64_of_base(truncated, 10)
                        } else {

                            ns_u64, _ = strconv.parse_u64_of_base(ns_str, 10)
                        }
                    }

                    fmt.sbprintf(&pd.result, "%010d\t:%d", ns_u64, i)
                    strings.write_byte(&pd.result, '\n')

                    big.zero(&ns)
                }

                if i >= pd.nn {
                    break
                }

                big.mul(&d_t, &d, &t)
                big.sub(&a_minus_dt, &a, &d_t)
                big.mul(&a, &a_minus_dt, &ten)

                big.mul(&n, &n, &ten)
            }
        }
    }

    if i % 10 != 0 {
        digits_needed := 10 - (i % 10)

        if digits_needed > 0 {

            power: big.Int
            defer big.destroy(&power)
            big.set(&power, 1)

            for _ in 0..<digits_needed {
                big.mul(&power, &power, &ten)
            }

            big.mul(&ns_temp, &ns, &power)
        } else {
            big.copy(&ns_temp, &ns)
        }

        ns_str, err := big.itoa(&ns_temp, 10)
        defer delete(ns_str)

        ns_u64: u64 = 0
        if err == nil && len(ns_str) > 0 {

            end := min(10, len(ns_str))
            truncated := ns_str[:end]
            ns_u64, _ = strconv.parse_u64_of_base(truncated, 10)
        }

        fmt.sbprintf(&pd.result, "%010d\t:%d", ns_u64, i)
    }
}

pidigits_checksum :: proc(bench: ^Benchmark) -> u32 {
    pd := cast(^Pidigits)bench

    result_str := strings.to_string(pd.result)
    defer delete(result_str)

    return checksum_string(result_str)
}

pidigits_prepare :: proc(bench: ^Benchmark) {
    pd := cast(^Pidigits)bench
    pd.nn = int(config_i64("Pidigits", "amount"))

    strings.builder_reset(&pd.result)
}

pidigits_cleanup :: proc(bench: ^Benchmark) {
    pd := cast(^Pidigits)bench

    strings.builder_reset(&pd.result)
}

create_pidigits :: proc() -> ^Benchmark {
    bench := new(Pidigits)
    bench.name = "Pidigits"
    bench.vtable = default_vtable()

    strings.builder_init(&bench.result)

    bench.vtable.run = pidigits_run
    bench.vtable.checksum = pidigits_checksum
    bench.vtable.prepare = pidigits_prepare
    bench.vtable.cleanup = pidigits_cleanup

    return cast(^Benchmark)bench
}