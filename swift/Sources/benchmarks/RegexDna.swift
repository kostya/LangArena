import Foundation
final class RegexDna: BenchmarkProtocol {
    private var seq: String = ""
    private var ilen: Int = 0
    private var clen: Int = 0
    private var output: String = ""
    func prepare() {
        output = ""
        // Используем Fasta для генерации данных
        let fasta = Fasta()
        fasta.n = iterations
        fasta.prepare()
        fasta.run()
        // Получаем вывод из Fasta
        seq = fasta.getOutput()
        // Эмулируем Crystal: общий размер в байтах
        ilen = seq.utf8.count
        // Считаем clen как сумму байтов не-заголовочных строк
        clen = 0
        let lines = seq.split(separator: "\n")
        for line in lines {
            let lineStr = String(line)
            if !lineStr.isEmpty && !lineStr.starts(with: ">") {
                clen += lineStr.utf8.count
            }
        }
        // Убираем заголовки из последовательности
        var seqBuilder = ""
        for line in lines {
            let lineStr = String(line)
            if !lineStr.isEmpty && !lineStr.starts(with: ">") {
                seqBuilder.append(lineStr)
            }
        }
        seq = seqBuilder
    }
    func run() {
        var outputBuilder = ""
        let patterns = [
            try! NSRegularExpression(pattern: "agggtaaa|tttaccct"),
            try! NSRegularExpression(pattern: "[cgt]gggtaaa|tttaccc[acg]"),
            try! NSRegularExpression(pattern: "a[act]ggtaaa|tttacc[agt]t"),
            try! NSRegularExpression(pattern: "ag[act]gtaaa|tttac[agt]ct"),
            try! NSRegularExpression(pattern: "agg[act]taaa|ttta[agt]cct"),
            try! NSRegularExpression(pattern: "aggg[acg]aaa|ttt[cgt]ccct"),
            try! NSRegularExpression(pattern: "agggt[cgt]aa|tt[acg]accct"),
            try! NSRegularExpression(pattern: "agggta[cgt]a|t[acg]taccct"),
            try! NSRegularExpression(pattern: "agggtaa[cgt]|[acg]ttaccct")
        ]
        for regex in patterns {
            let matches = regex.matches(in: seq, range: NSRange(seq.startIndex..., in: seq))
            let count = matches.count
            outputBuilder.append("\(regex.pattern) \(count)\n")
        }
        let replacements = [
            "B": "(c|g|t)",
            "D": "(a|g|t)", 
            "H": "(a|c|t)",
            "K": "(g|t)",
            "M": "(a|c)",
            "N": "(a|c|g|t)",
            "R": "(a|g)",
            "S": "(c|t)",
            "V": "(a|c|g)",
            "W": "(a|t)",
            "Y": "(c|t)"
        ]
        var processed = seq
        for (key, value) in replacements {
            processed = processed.replacingOccurrences(
                of: key, 
                with: value, 
                options: .regularExpression
            )
        }
        outputBuilder.append("\n")
        outputBuilder.append("\(ilen)\n")
        outputBuilder.append("\(clen)\n")
        outputBuilder.append("\(processed.count)\n")
        output = outputBuilder
    }
    var result: Int64 {
        let checksum = Helper.checksum(output)
        return Int64(bitPattern: UInt64(checksum))
    }
}