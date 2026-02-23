import Foundation

final class Matmul1T: BenchmarkProtocol {
  private var n: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {
    n = configValue("n") ?? 0
  }

  private func matmul(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    let m = a.count
    let n = a[0].count
    let p = b[0].count

    var b2 = [[Double]](repeating: [Double](repeating: 0, count: n), count: p)
    for i in 0..<n {
      for j in 0..<p {
        b2[j][i] = b[i][j]
      }
    }

    var c = [[Double]](repeating: [Double](repeating: 0, count: p), count: m)
    for i in 0..<m {
      let ai = a[i]
      var ci = c[i]
      for j in 0..<p {
        var s = 0.0
        let b2j = b2[j]
        for k in 0..<n {
          s += ai[k] * b2j[k]
        }
        ci[j] = s
      }
      c[i] = ci
    }
    return c
  }

  private func matgen(_ n: Int) -> [[Double]] {
    let tmp = 1.0 / Double(n) / Double(n)
    var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
    for i in 0..<n {
      for j in 0..<n {
        a[i][j] = tmp * Double(i - j) * Double(i + j)
      }
    }
    return a
  }

  func run(iterationId: Int) {
    let a = matgen(Int(n))
    let b = matgen(Int(n))
    let c = matmul(a, b)
    let center = c[Int(n) / 2][Int(n) / 2]
    resultVal &+= Helper.checksumF64(center)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}
  func name() -> String {
    return "Matmul::T1"
  }
}
