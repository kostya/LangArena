namespace Benchmarks

open System

type Sieve() =
    inherit Benchmark()

    let mutable limit = 0L
    let mutable checksum = 0u

    override this.Prepare() =
        limit <- this.ConfigVal("limit")
        checksum <- 0u

    override this.Name = "Etc::Sieve"

    override this.Checksum = checksum

    override this.Run(_: int64) =
        let lim = int limit
        let primes = Array.create (lim + 1) 1uy
        primes.[0] <- 0uy
        primes.[1] <- 0uy

        let sqrtLimit = int (sqrt (float lim))

        for p in 2 .. sqrtLimit do
            if primes.[p] = 1uy then
                let mutable multiple = p * p
                while multiple <= lim do
                    primes.[multiple] <- 0uy
                    multiple <- multiple + p

        let mutable lastPrime = 2
        let mutable count = 1

        let mutable n = 3
        while n <= lim do
            if primes.[n] = 1uy then
                lastPrime <- n
                count <- count + 1
            n <- n + 2

        checksum <- checksum + (uint32 (lastPrime + count))