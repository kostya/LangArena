package benchmark

import "core:slice"

Fannkuchredux :: struct {
    using base: Benchmark,
    n: int,
    result_val: i32,
}

fannkuchredux_run :: proc(n: int) -> (checksum: int, max_flips: int) {
    n := min(n, 32)
    perm1: [32]int
    perm: [32]int
    count: [32]int

    for i in 0..<n {
        perm1[i] = i
    }

    max_flips = 0
    perm_count := 0
    checksum = 0
    r := n

    for {
        for r > 1 {
            count[r - 1] = r
            r -= 1
        }

        copy(perm[:n], perm1[:n])

        flips_count := 0
        k := perm[0]

        for k != 0 {
            slice.reverse(perm[:k + 1])
            flips_count += 1
            k = perm[0]
        }

        max_flips = max(max_flips, flips_count)
        checksum += flips_count if perm_count % 2 == 0 else -flips_count

        for {
            if r == n {
                return
            }

            perm0 := perm1[0]
            for i in 0..<r {
                perm1[i] = perm1[i + 1]
            }
            perm1[r] = perm0

            count[r] -= 1
            if count[r] > 0 {
                break
            }
            r += 1
        }
        perm_count += 1
    }
}

fannkuchredux_bench_run :: proc(bench: ^Benchmark, iteration_id: int) {
    fr := cast(^Fannkuchredux)bench

    checksum, max_flips := fannkuchredux_run(fr.n)
    fr.result_val += i32(checksum * 100 + max_flips)
}

fannkuchredux_checksum :: proc(bench: ^Benchmark) -> u32 {
    fr := cast(^Fannkuchredux)bench
    return u32(fr.result_val)
}

fannkuchredux_prepare :: proc(bench: ^Benchmark) {
    fr := cast(^Fannkuchredux)bench
    fr.n = int(config_i64("Fannkuchredux", "n"))
}

create_fannkuchredux :: proc() -> ^Benchmark {
    fr := new(Fannkuchredux)
    fr.name = "Fannkuchredux"
    fr.vtable = default_vtable()

    fr.vtable.run = fannkuchredux_bench_run
    fr.vtable.checksum = fannkuchredux_checksum
    fr.vtable.prepare = fannkuchredux_prepare

    return cast(^Benchmark)fr
}