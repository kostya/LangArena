import std/[math, strutils]
import ../benchmark
import ../helper

type
  Sieve* = ref object of Benchmark
    n: int64
    checksumVal: uint32

proc newSieve(): Benchmark =
  Sieve()

method name(self: Sieve): string = "Etc::Sieve"

method prepare(self: Sieve) =
  self.n = self.config_val("limit")
  self.checksumVal = 0'u32

method run(self: Sieve, iteration_id: int) =
  let lim = self.n.int
  var primes = newSeq[uint8](lim + 1)
  for i in 0..lim:
    primes[i] = 1
  primes[0] = 0
  primes[1] = 0

  let sqrtLimit = int(sqrt(float(lim)))

  for p in 2..sqrtLimit:
    if primes[p] == 1:
      var multiple = p * p
      while multiple <= lim:
        primes[multiple] = 0
        multiple += p

  var lastPrime = 2
  var count = 1

  var n = 3
  while n <= lim:
    if primes[n] == 1:
      lastPrime = n
      count += 1
    n += 2

  self.checksumVal += uint32(lastPrime + count)

method checksum(self: Sieve): uint32 =
  self.checksumVal

registerBenchmark("Etc::Sieve", newSieve)
