from std.math import sqrt
from helper import Helper
from benchmark import Benchmark, Config


struct Sieve(Benchmark):
    var limit: Int
    var checksum_: UInt32

    def __init__(out self, config: Config) raises:
        self.limit = config.get_i64("Etc::Sieve", "limit")
        self.checksum_ = 0

    def class_name(self) -> String:
        return "Etc::Sieve"

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var limit = self.limit
        var primes = List[UInt8](length=limit + 1, fill=1)
        primes[0] = 0
        primes[1] = 0

        var sqrt_limit = Int(sqrt(Float64(limit)))

        for p in range(2, sqrt_limit + 1):
            if primes[p] == 1:
                var multiple = p * p
                while multiple <= limit:
                    primes[multiple] = 0
                    multiple += p

        var last_prime: Int = 2
        var count: Int = 1

        var n = 3
        while n <= limit:
            if primes[n] == 1:
                last_prime = n
                count += 1
            n += 2

        self.checksum_ += UInt32(last_prime + count)

    def checksum(mut self) -> UInt32:
        return self.checksum_
