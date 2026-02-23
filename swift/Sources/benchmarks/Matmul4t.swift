import Dispatch
import Foundation

class Matmul4T: BenchmarkProtocol {
  public var n: Int64 = 0
  public var resultVal: UInt32 = 0
  private let lock = NSLock()

  init() {
    n = configValue("n") ?? 0
  }

  func getNumThreads() -> Int {
    return 4
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

  private func matmulParallel(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    let size = a.count
    let numThreads = getNumThreads()

    var bT = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
    for i in 0..<size {
      for j in 0..<size {
        bT[j][i] = b[i][j]
      }
    }

    var c = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)

    DispatchQueue.concurrentPerform(iterations: numThreads) { threadId in
      let startRow = threadId
      for i in stride(from: startRow, to: size, by: numThreads) {
        let ai = a[i]
        var row = [Double](repeating: 0.0, count: size)

        for j in 0..<size {
          var sum = 0.0
          let bTj = bT[j]

          for k in 0..<size {
            sum += ai[k] * bTj[k]
          }

          row[j] = sum
        }

        lock.lock()
        c[i] = row
        lock.unlock()
      }
    }

    return c
  }

  func run(iterationId: Int) {
    let a = matgen(Int(n))
    let b = matgen(Int(n))
    let c = matmulParallel(a, b)
    let center = c[Int(n) / 2][Int(n) / 2]
    resultVal &+= Helper.checksumF64(center)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func prepare() {}

  func name() -> String {
    return "Matmul::T4"
  }
}
