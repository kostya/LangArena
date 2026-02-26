import Foundation

final class Sieve: BenchmarkProtocol {
  private var limitVal: Int64 = 0
  private var checksumVal: UInt32 = 0

  init() {
    limitVal = configValue("limit") ?? 0
  }

  func run(iterationId: Int) {
    let limit = Int(limitVal)
    var primes = [UInt8](repeating: 1, count: limit + 1)
    primes[0] = 0
    primes[1] = 0

    let sqrtLimit = Int(sqrt(Double(limit)))

    for p in 2...sqrtLimit {
      if primes[p] == 1 {
        var multiple = p * p
        while multiple <= limit {
          primes[multiple] = 0
          multiple += p
        }
      }
    }

    var lastPrime = 2
    var count = 1

    var n = 3
    while n <= limit {
      if primes[n] == 1 {
        lastPrime = n
        count += 1
      }
      n += 2
    }

    checksumVal &+= UInt32(lastPrime + count)
  }

  var checksum: UInt32 {
    return checksumVal
  }

  func prepare() {}

  func name() -> String {
    return "Etc::Sieve"
  }
}
