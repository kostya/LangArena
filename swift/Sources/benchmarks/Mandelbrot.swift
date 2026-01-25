import Foundation
final class Mandelbrot: BenchmarkProtocol {
    private var n: Int = 0
    private var output: [UInt8] = []
    private static let ITER = 50
    private static let LIMIT = 2.0
    init() {
        n = iterations
    }
    func prepare() {
        let w = n
        let h = n
        let header = "P4\n\(w) \(h)\n"
        let dataSize = ((w + 7) / 8) * h
        output = [UInt8](repeating: 0, count: header.utf8.count + dataSize)
        // Копируем header исправленным способом
        let headerBytes = [UInt8](header.utf8)
        output[0..<headerBytes.count] = headerBytes[0..<headerBytes.count]
    }
    func run() {
        let w = n
        let h = n
        var bitNum = 0
        var byteAcc: UInt8 = 0
        var outputIndex = "P4\n\(w) \(h)\n".utf8.count
        for y in 0..<h {
            for x in 0..<w {
                var zr = 0.0
                var zi = 0.0
                var tr = 0.0
                var ti = 0.0
                let cr = 2.0 * Double(x) / Double(w) - 1.5
                let ci = 2.0 * Double(y) / Double(h) - 1.0
                var i = 0
                while i < Mandelbrot.ITER && tr + ti <= Mandelbrot.LIMIT * Mandelbrot.LIMIT {
                    zi = 2.0 * zr * zi + ci
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1
                }
                byteAcc <<= 1
                if tr + ti <= Mandelbrot.LIMIT * Mandelbrot.LIMIT {
                    byteAcc |= 0x01
                }
                bitNum += 1
                if bitNum == 8 {
                    output[outputIndex] = byteAcc
                    outputIndex += 1
                    byteAcc = 0
                    bitNum = 0
                } else if x == w - 1 {
                    if bitNum > 0 {
                        byteAcc <<= (8 - bitNum)
                        output[outputIndex] = byteAcc
                        outputIndex += 1
                    }
                    byteAcc = 0
                    bitNum = 0
                }
            }
        }
    }
    var result: Int64 {
        let checksum = Helper.checksum(output)
        return Int64(checksum)
    }
}