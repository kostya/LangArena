mutable struct Sieve <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Sieve()
        n = Helper.config_i64("Etc::Sieve", "limit")
        new(n, UInt32(0))
    end
end

name(b::Sieve)::String = "Etc::Sieve"

function run(b::Sieve, iteration_id::Int64)
    lim = Int(b.n)
    primes = fill(UInt8(1), lim + 1)
    primes[1] = UInt8(0)
    primes[2] = UInt8(0)

    sqrt_limit = isqrt(lim)

    for p = 2:sqrt_limit
        if primes[p+1] == 0x01
            start = p * p
            for multiple = start:p:lim
                primes[multiple+1] = 0x00
            end
        end
    end

    last_prime = 2
    count = 1

    for n = 3:2:lim
        if primes[n+1] == 0x01
            last_prime = n
            count += 1
        end
    end

    b.result += UInt32(last_prime + count)
end

checksum(b::Sieve)::UInt32 = b.result
