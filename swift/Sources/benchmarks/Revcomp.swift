import Foundation

final class Revcomp: BenchmarkProtocol {
    private var input: String = ""
    private var output: String = ""
    
    private static var lookupTable: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 256)
        
        for i in 0..<256 {
            table[i] = UInt8(i)
        }
        
        let from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        let to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
        
        let fromBytes = from.utf8.map { $0 }
        let toBytes = to.utf8.map { $0 }
        
        for i in 0..<min(fromBytes.count, toBytes.count) {
            let index = Int(fromBytes[i])
            if index < 256 {
                table[index] = toBytes[i]
            }
        }
        
        return table
    }()
    
    func prepare() {
        output = ""
        let fasta = Fasta()
        fasta.n = configValue("n") ?? 0
        fasta.prepare()
        fasta.run(iterationId: 0)
        let fastaResult = fasta.getOutput()
        
        let lines = fastaResult.split(separator: "\n")
        var seq = ""
        for line in lines {
            let lineStr = String(line)
            if !lineStr.starts(with: ">") {
                seq += lineStr
            } else {
                seq += "\n---\n"
            }
        }
        input = seq
    }
    
    private func revcomp(_ seq: String) -> String {
        let bytes = Array(seq.utf8)
        let count = bytes.count
        var resultBytes = [UInt8](repeating: 0, count: count)
        let lookup = Self.lookupTable
        
        for i in 0..<count {
            let sourceByte = bytes[count - 1 - i]
            resultBytes[i] = lookup[Int(sourceByte)]
        }
        
        var result = ""
        var lineStart = 0
        
        while lineStart < count {
            let lineEnd = min(lineStart + 60, count)
            let lineBytes = resultBytes[lineStart..<lineEnd]
            
            if let line = String(bytes: lineBytes, encoding: .utf8) {
                result.append(line)
            }
            result.append("\n")
            
            lineStart = lineEnd
        }
        
        return result
    }
    
    func run(iterationId: Int) {
        output.append(revcomp(input))
    }
    
    var checksum: UInt32 {
        return Helper.checksum(output)
    }
}