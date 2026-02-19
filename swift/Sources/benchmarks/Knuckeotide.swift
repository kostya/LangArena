import Foundation

final class Knuckeotide: BenchmarkProtocol {
  private var seq: [Character] = []
  private var output: String = ""

  func prepare() {
    output = ""

    let fasta = Fasta()
    fasta.n = configValue("n") ?? 0
    fasta.prepare()
    fasta.run(iterationId: 0)
    let res = fasta.getOutput()

    var three = false
    var seqio: [Character] = []

    for line in res.split(separator: "\n") {
      let lineStr = String(line)
      if lineStr.hasPrefix(">THREE") {
        three = true
        continue
      }
      if three {
        seqio.append(contentsOf: lineStr.trimmingCharacters(in: .whitespaces))
      }
    }

    seq = seqio
  }

  private func frequency(_ seq: [Character], length: Int) -> (n: Int, table: [String: Int]) {
    let n = seq.count - length + 1
    var table: [String: Int] = [:]
    table.reserveCapacity(n)

    for i in 0..<n {
      let sub = String(seq[i..<(i + length)])
      table[sub, default: 0] += 1
    }

    return (n, table)
  }

  private func sortByFreq(_ seq: [Character], length: Int) {
    let (n, table) = frequency(seq, length: length)

    let sorted = table.sorted {
      if $0.value != $1.value {
        return $0.value > $1.value
      }
      return $0.key < $1.key
    }

    for (key, value) in sorted {
      let freq = Double(value * 100) / Double(n)
      output += "\(key.uppercased()) \(String(format: "%.3f", freq))\n"
    }

    output += "\n"
  }

  private func findSeq(_ seq: [Character], s: String) {
    let (_, table) = frequency(seq, length: s.count)
    let count = table[s, default: 0]
    output += "\(count)\t\(s.uppercased())\n"
  }

  func run(iterationId: Int) {
    output.reserveCapacity(50000)

    for i in 1...2 {
      sortByFreq(seq, length: i)
    }

    let searches = ["ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"]
    for s in searches {
      findSeq(seq, s: s)
    }
  }

  var checksum: UInt32 {
    return Helper.checksum(output)
  }
}
