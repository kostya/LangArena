import Foundation

final class Fasta: BenchmarkProtocol {
  var n: Int64 = 0
  private var output: String = ""

  init() {
    n = configValue("n") ?? 0
  }

  func prepare() {
    output = ""
  }

  private static let LINE_LENGTH = 60
  private static let IUB: [(Character, Double)] = [
    ("a", 0.27), ("c", 0.39), ("g", 0.51), ("t", 0.78),
    ("B", 0.8), ("D", 0.8200000000000001), ("H", 0.8400000000000001),
    ("K", 0.8600000000000001), ("M", 0.8800000000000001), ("N", 0.9000000000000001),
    ("R", 0.9200000000000002), ("S", 0.9400000000000002), ("V", 0.9600000000000002),
    ("W", 0.9800000000000002), ("Y", 1.0000000000000002),
  ]
  private static let HOMO: [(Character, Double)] = [
    ("a", 0.302954942668), ("c", 0.5009432431601),
    ("g", 0.6984905497992), ("t", 1.0),
  ]
  private static let ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

  private func selectRandom(_ genelist: [(Character, Double)]) -> Character {
    let r = Helper.nextFloat()
    if r < genelist[0].1 { return genelist[0].0 }
    var lo = 0
    var hi = genelist.count - 1
    while hi > lo + 1 {
      let i = (hi + lo) / 2
      if r < genelist[i].1 {
        hi = i
      } else {
        lo = i
      }
    }
    return genelist[hi].0
  }

  private func makeRandomFasta(id: String, desc: String, genelist: [(Character, Double)], n: Int) {
    output.append(">\(id) \(desc)\n")
    var todo = n
    while todo > 0 {
      let m = min(todo, Fasta.LINE_LENGTH)
      var buffer = [Character]()
      buffer.reserveCapacity(m)
      for _ in 0..<m {
        buffer.append(selectRandom(genelist))
      }
      output.append(String(buffer))
      output.append("\n")
      todo -= Fasta.LINE_LENGTH
    }
  }

  private func makeRepeatFasta(id: String, desc: String, s: String, n: Int) {
    output.append(">\(id) \(desc)\n")
    var todo = n
    var k = 0
    let kn = s.count
    while todo > 0 {
      var m = min(todo, Fasta.LINE_LENGTH)
      while m >= kn - k {
        let start = s.index(s.startIndex, offsetBy: k)
        let end = s.endIndex
        output.append(String(s[start..<end]))
        m -= kn - k
        k = 0
      }
      if m > 0 {
        let start = s.index(s.startIndex, offsetBy: k)
        let end = s.index(start, offsetBy: m)
        output.append(String(s[start..<end]))
        k += m
      }
      output.append("\n")
      todo -= Fasta.LINE_LENGTH
    }
  }

  func run(iterationId: Int) {
    makeRepeatFasta(id: "ONE", desc: "Homo sapiens alu", s: Fasta.ALU, n: Int(n * 2))
    makeRandomFasta(id: "TWO", desc: "IUB ambiguity codes", genelist: Fasta.IUB, n: Int(n * 3))
    makeRandomFasta(
      id: "THREE", desc: "Homo sapiens frequency", genelist: Fasta.HOMO, n: Int(n * 5))
  }

  var checksum: UInt32 {
    return Helper.checksum(output)
  }

  func getOutput() -> String {
    return output
  }
  func name() -> String {
    return "CLBG::Fasta"
  }
}
