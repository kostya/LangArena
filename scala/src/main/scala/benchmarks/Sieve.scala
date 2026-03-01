package benchmarks

import java.{util => ju}

class Sieve extends Benchmark:
  private var limit: Long = 0L
  private var checksumVal: Long = 0L

  override def name(): String = "Etc::Sieve"

  override def prepare(): Unit =
    limit = configVal("limit")

  override def run(iterationId: Int): Unit =
    val lim = limit.toInt
    val primes = new Array[Byte](lim + 1)
    ju.Arrays.fill(primes, 1.toByte)
    primes(0) = 0
    primes(1) = 0

    val sqrtLimit = math.sqrt(lim).toInt

    var p = 2
    while p <= sqrtLimit do
      if primes(p) == 1 then
        var multiple = p * p
        while multiple <= lim do
          primes(multiple) = 0
          multiple += p
      p += 1

    var lastPrime = 2
    var count = 1

    var n = 3
    while n <= lim do
      if primes(n) == 1 then
        lastPrime = n
        count += 1
      n += 2

    checksumVal = (checksumVal + lastPrime + count) & 0xffffffffL

  override def checksum(): Long = checksumVal
