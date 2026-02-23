import Foundation

final class Primes: BenchmarkProtocol {
  private var limitVal: Int64 = 0
  private var prefixVal: Int64 = 0
  private var resultVal: UInt32 = 5432

  init() {
    limitVal = configValue("limit") ?? 0
    prefixVal = configValue("prefix") ?? 32338
  }

  private class Node {
    var children: [Node?] = Array(repeating: nil, count: 10)
    var terminal: Bool = false
  }

  private func generatePrimes(limit: Int) -> [Int] {
    guard limit >= 2 else { return [] }

    var isPrime = [Bool](repeating: true, count: limit + 1)
    isPrime[0] = false
    isPrime[1] = false

    let sqrtLimit = Int(sqrt(Double(limit)))

    for p in 2...sqrtLimit {
      if isPrime[p] {
        var multiple = p * p
        while multiple <= limit {
          isPrime[multiple] = false
          multiple += p
        }
      }
    }

    let estimatedSize = Int(Double(limit) / (log(Double(limit)) - 1.1))
    var primes = [Int]()
    primes.reserveCapacity(estimatedSize)

    for i in 2...limit {
      if isPrime[i] {
        primes.append(i)
      }
    }

    return primes
  }

  private func buildTrie(primes: [Int]) -> Node {
    let root = Node()

    for prime in primes {
      var current = root
      let digits = String(prime)

      for ch in digits {
        let digit = Int(ch.asciiValue! - Character("0").asciiValue!)
        if current.children[digit] == nil {
          current.children[digit] = Node()
        }
        current = current.children[digit]!
      }
      current.terminal = true
    }

    return root
  }

  private func findPrimesWithPrefix(root: Node, prefix: Int) -> [Int] {
    let prefixStr = String(prefix)
    var current = root

    for ch in prefixStr {
      let digit = Int(ch.asciiValue! - Character("0").asciiValue!)
      guard let next = current.children[digit] else {
        return []
      }
      current = next
    }

    var results = [Int]()
    var queue = [(node: Node, number: Int)]()
    queue.append((current, prefix))

    while !queue.isEmpty {
      let (node, number) = queue.removeFirst()

      if node.terminal {
        results.append(number)
      }

      for digit in 0..<10 {
        if let child = node.children[digit] {
          queue.append((child, number * 10 + digit))
        }
      }
    }

    results.sort()
    return results
  }

  func run(iterationId: Int) {
    let primes = generatePrimes(limit: Int(limitVal))
    let trie = buildTrie(primes: primes)
    let results = findPrimesWithPrefix(root: trie, prefix: Int(prefixVal))

    resultVal &+= UInt32(results.count)
    for prime in results {
      resultVal &+= UInt32(prime)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}

  func name() -> String {
    return "Etc::Primes"
  }
}
