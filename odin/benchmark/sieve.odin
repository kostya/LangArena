package benchmark

import "core:math"
import "core:slice"
import "core:mem"

Sieve :: struct {
    using base: Benchmark,
    limit: int,
    checksum_val: u32,
}

sieve_prepare :: proc(bench: ^Benchmark) {
    s := cast(^Sieve)bench
    s.limit = int(config_i64("Etc::Sieve", "limit"))
    s.checksum_val = 0
}

sieve_run :: proc(bench: ^Benchmark, iteration_id: int) {
    s := cast(^Sieve)bench
    lim := s.limit

    primes := make([]u8, lim + 1)
    defer delete(primes)

    for i in 0..=lim {
        primes[i] = 1
    }
    primes[0] = 0
    primes[1] = 0

    sqrt_limit := int(math.sqrt(f64(lim)))

    for p in 2..=sqrt_limit {
        if primes[p] == 1 {
            for multiple := p * p; multiple <= lim; multiple += p {
                primes[multiple] = 0
            }
        }
    }

    last_prime := 2
    count := 1

    n := 3
    for n <= lim {
        if primes[n] == 1 {
            last_prime = n
            count += 1
        }
        n += 2
    }

    s.checksum_val += u32(last_prime + count)
}

sieve_checksum :: proc(bench: ^Benchmark) -> u32 {
    s := cast(^Sieve)bench
    return s.checksum_val
}

create_sieve :: proc() -> ^Benchmark {
    s := new(Sieve)
    s.name = "Etc::Sieve"
    s.vtable = default_vtable()

    s.vtable.run = sieve_run
    s.vtable.checksum = sieve_checksum
    s.vtable.prepare = sieve_prepare

    return cast(^Benchmark)s
}