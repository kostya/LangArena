import Foundation

final class Jaro: BenchmarkProtocol {
  private var count: Int = 0
  private var size: Int = 0
  private var pairs: [(String, String)] = []
  private var resultVal: UInt32 = 0

  func prepare() {
    count = Int(configValue("count") ?? 0)
    size = Int(configValue("size") ?? 0)
    pairs = generatePairStrings(n: count, m: size)
    resultVal = 0
  }

  private func generatePairStrings(n: Int, m: Int) -> [(String, String)] {
    var pairs: [(String, String)] = []
    pairs.reserveCapacity(n)
    let chars = Array("abcdefghij")

    for _ in 0..<n {
      let len1 = Helper.nextInt(max: m) + 4
      let len2 = Helper.nextInt(max: m) + 4

      var str1 = ""
      var str2 = ""
      str1.reserveCapacity(len1)
      str2.reserveCapacity(len2)

      for _ in 0..<len1 {
        str1.append(chars[Helper.nextInt(max: 10)])
      }
      for _ in 0..<len2 {
        str2.append(chars[Helper.nextInt(max: 10)])
      }

      pairs.append((str1, str2))
    }

    return pairs
  }

  private func jaro(_ s1: String, _ s2: String) -> Double {

    guard let bytes1 = s1.data(using: .ascii)?.map({ $0 }),
      let bytes2 = s2.data(using: .ascii)?.map({ $0 })
    else {
      return 0.0
    }

    let len1 = bytes1.count
    let len2 = bytes2.count

    if len1 == 0 || len2 == 0 {
      return 0.0
    }

    var matchDist = max(len1, len2) / 2 - 1
    if matchDist < 0 {
      matchDist = 0
    }

    var s1Matches = [Bool](repeating: false, count: len1)
    var s2Matches = [Bool](repeating: false, count: len2)

    var matches = 0
    for i in 0..<len1 {
      let start = max(0, i - matchDist)
      let end = min(len2 - 1, i + matchDist)

      var found = false
      var j = start
      while j <= end && !found {
        if !s2Matches[j] && bytes1[i] == bytes2[j] {
          s1Matches[i] = true
          s2Matches[j] = true
          matches += 1
          found = true
        }
        j += 1
      }
    }

    if matches == 0 {
      return 0.0
    }

    var transpositions = 0
    var k = 0
    for i in 0..<len1 {
      if s1Matches[i] {
        while k < len2 && !s2Matches[k] {
          k += 1
        }
        if k < len2 {
          if bytes1[i] != bytes2[k] {
            transpositions += 1
          }
          k += 1
        }
      }
    }
    transpositions /= 2

    let m = Double(matches)
    return (m / Double(len1) + m / Double(len2) + (m - Double(transpositions)) / m) / 3.0
  }

  func run(iterationId: Int) {
    for (s1, s2) in pairs {
      resultVal = resultVal &+ UInt32(jaro(s1, s2) * 1000)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return "Distance::Jaro"
  }
}

final class NGram: BenchmarkProtocol {
  private var count: Int = 0
  private var size: Int = 0
  private var pairs: [(String, String)] = []
  private var resultVal: UInt32 = 0
  private let n = 4

  func prepare() {
    count = Int(configValue("count") ?? 0)
    size = Int(configValue("size") ?? 0)
    pairs = generatePairStrings(n: count, m: size)
    resultVal = 0
  }

  private func generatePairStrings(n: Int, m: Int) -> [(String, String)] {
    var pairs: [(String, String)] = []
    pairs.reserveCapacity(n)
    let chars = Array("abcdefghij")

    for _ in 0..<n {
      let len1 = Helper.nextInt(max: m) + 4
      let len2 = Helper.nextInt(max: m) + 4

      var str1 = ""
      var str2 = ""
      str1.reserveCapacity(len1)
      str2.reserveCapacity(len2)

      for _ in 0..<len1 {
        str1.append(chars[Helper.nextInt(max: 10)])
      }
      for _ in 0..<len2 {
        str2.append(chars[Helper.nextInt(max: 10)])
      }

      pairs.append((str1, str2))
    }

    return pairs
  }

  private func ngram(_ s1: String, _ s2: String) -> Double {
    guard let bytes1 = s1.data(using: .ascii)?.map({ $0 }),
      let bytes2 = s2.data(using: .ascii)?.map({ $0 })
    else {
      return 0.0
    }

    let len1 = bytes1.count
    let len2 = bytes2.count

    if len1 < n || len2 < n {
      return 0.0
    }

    var grams1: [UInt32: Int] = [:]
    grams1.reserveCapacity(len1)

    for i in 0...(len1 - n) {
      let gram =
        (UInt32(bytes1[i]) << 24) | (UInt32(bytes1[i + 1]) << 16) | (UInt32(bytes1[i + 2]) << 8)
        | UInt32(bytes1[i + 3])

      if let count = grams1[gram] {
        grams1[gram] = count + 1
      } else {
        grams1[gram] = 1
      }
    }

    var grams2: [UInt32: Int] = [:]
    grams2.reserveCapacity(len2)
    var intersection = 0

    for i in 0...(len2 - n) {
      let gram =
        (UInt32(bytes2[i]) << 24) | (UInt32(bytes2[i + 1]) << 16) | (UInt32(bytes2[i + 2]) << 8)
        | UInt32(bytes2[i + 3])

      if let count = grams2[gram] {
        grams2[gram] = count + 1
      } else {
        grams2[gram] = 1
      }

      if let count1 = grams1[gram], grams2[gram]! <= count1 {
        intersection += 1
      }
    }

    let total = grams1.count + grams2.count
    return total > 0 ? Double(intersection) / Double(total) : 0.0
  }

  func run(iterationId: Int) {
    for (s1, s2) in pairs {
      resultVal = resultVal &+ UInt32(ngram(s1, s2) * 1000)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return "Distance::NGram"
  }
}
