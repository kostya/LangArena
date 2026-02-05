import Foundation

final class Revcomp: BenchmarkProtocol {
    private var input: String = ""
    private var resultVal: UInt32 = 0

    private static let lookupTable: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 256)

        for i in 0..<256 {
            table[i] = UInt8(i)
        }

        let from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        let to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

        let fromBytes = Array(from.utf8)
        let toBytes = Array(to.utf8)

        for i in 0..<min(fromBytes.count, toBytes.count) {
            table[Int(fromBytes[i])] = toBytes[i]
        }

        return table
    }()

    func prepare() {
        let fasta = Fasta()
        fasta.n = configValue("n") ?? 0
        fasta.prepare()
        fasta.run(iterationId: 0)
        let fastaResult = fasta.getOutput()

        var seq = ""
        seq.reserveCapacity(fastaResult.count)

        var start = fastaResult.startIndex
        let end = fastaResult.endIndex

        while start < end {
            let lineEnd = fastaResult[start...].firstIndex(of: "\n") ?? end
            let line = fastaResult[start..<lineEnd]

            if line.starts(with: ">") {
                seq.append("\n---\n")
            } else {
                seq.append(contentsOf: line)
            }

            start = lineEnd == end ? end : fastaResult.index(after: lineEnd)
        }

        input = seq
    }

    private func revcomp(_ seq: String) -> String {
        let lookup = Self.lookupTable
        let bytes = Array(seq.utf8)
        let count = bytes.count

        let lines = (count + 59) / 60
        var resultBytes = [UInt8]()
        resultBytes.reserveCapacity(count + lines)

        var pos = count

        while pos > 0 {
            let chunkStart = max(pos - 60, 0)
            let chunkSize = pos - chunkStart

            for i in stride(from: pos - 1, through: chunkStart, by: -1) {
                resultBytes.append(lookup[Int(bytes[i])])
            }

            resultBytes.append(10) 
            pos = chunkStart
        }

        if count % 60 == 0 && count > 0 {
            resultBytes.removeLast()
        }

        return String(decoding: resultBytes, as: UTF8.self)
    }

    func run(iterationId: Int) {
        resultVal &+= Helper.checksum(revcomp(input))
    }

    var checksum: UInt32 {
        return resultVal
    }
}