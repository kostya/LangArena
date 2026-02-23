import Foundation

final class Mandelbrot: BenchmarkProtocol {
  private var w: Int64 = 0
  private var h: Int64 = 0
  private var output: [UInt8] = []
  private static let ITER = 50
  private static let LIMIT = 2.0

  init() {
    w = configValue("w") ?? 0
    h = configValue("h") ?? 0
  }

  func prepare() {

    output = []
  }

  func run(iterationId: Int) {
    let width = Int(w)
    let height = Int(h)

    let header = "P4\n\(width) \(height)\n"
    let headerBytes = [UInt8](header.utf8)
    output.append(contentsOf: headerBytes)

    var bitNum = 0
    var byteAcc: UInt8 = 0

    for y in 0..<height {
      for x in 0..<width {
        var zr = 0.0
        var zi = 0.0
        var tr = 0.0
        var ti = 0.0
        let cr = 2.0 * Double(x) / Double(width) - 1.5
        let ci = 2.0 * Double(y) / Double(height) - 1.0
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
          output.append(byteAcc)
          byteAcc = 0
          bitNum = 0
        } else if x == width - 1 {
          if bitNum > 0 {
            byteAcc <<= (8 - bitNum)
            output.append(byteAcc)
          }
          byteAcc = 0
          bitNum = 0
        }
      }
    }
  }

  var checksum: UInt32 {
    return Helper.checksum(output)
  }

  func name() -> String {
    return "CLBG::Mandelbrot"
  }
}
