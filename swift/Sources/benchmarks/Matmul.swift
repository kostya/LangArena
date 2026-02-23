import Dispatch
import Foundation

class MatmulBase: BenchmarkProtocol {
  private var _n: Int64 = 0
  private var _resultVal: UInt32 = 0
  private var _a: [[Double]] = []
  private var _b: [[Double]] = []
  private let lock = NSLock()

  var n: Int64 {
    return _n
  }

  var resultVal: UInt32 {
    get { return _resultVal }
    set { _resultVal = newValue }
  }

  var a: [[Double]] {
    return _a
  }

  var b: [[Double]] {
    return _b
  }

  func prepare() {
    _n = configValue("n") ?? 0
    _a = matgen(Int(_n))
    _b = matgen(Int(_n))
    _resultVal = 0
  }

  func matgen(_ n: Int) -> [[Double]] {
    let tmp = 1.0 / Double(n) / Double(n)
    var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)

    for i in 0..<n {
      for j in 0..<n {
        a[i][j] = tmp * Double(i - j) * Double(i + j)
      }
    }
    return a
  }

  func transpose(_ b: [[Double]]) -> [[Double]] {
    let n = b.count
    var bT = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)

    for i in 0..<n {
      for j in 0..<n {
        bT[j][i] = b[i][j]
      }
    }
    return bT
  }

  func matmulSequential(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    let n = a.count
    let bT = transpose(b)
    var c = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)

    for i in 0..<n {
      let ai = a[i]
      var ci = c[i]
      for j in 0..<n {
        var s = 0.0
        let bTj = bT[j]

        for k in 0..<n {
          s += ai[k] * bTj[k]
        }
        ci[j] = s
      }
      c[i] = ci
    }
    return c
  }

  func matmulParallel(_ a: [[Double]], _ b: [[Double]], numThreads: Int) -> [[Double]] {
    let n = a.count
    let bT = transpose(b)
    var c = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)

    DispatchQueue.concurrentPerform(iterations: numThreads) { threadId in
      let startRow = threadId
      for i in stride(from: startRow, to: n, by: numThreads) {
        let ai = a[i]
        var row = [Double](repeating: 0.0, count: n)

        for j in 0..<n {
          var sum = 0.0
          let bTj = bT[j]

          for k in 0..<n {
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

  func getNumThreads() -> Int {
    return 1
  }

  func run(iterationId: Int) {

  }

  var checksum: UInt32 {
    return _resultVal
  }

  func name() -> String {
    return "MatmulBase"
  }
}

final class Matmul1T: MatmulBase {
  override func name() -> String {
    return "Matmul::Single"
  }

  override func run(iterationId: Int) {
    let c = matmulSequential(a, b)
    let center = c[Int(n) / 2][Int(n) / 2]
    resultVal &+= Helper.checksumF64(center)
  }
}

class MatmulParallelBase: MatmulBase {
  override func getNumThreads() -> Int {
    return 4
  }

  override func run(iterationId: Int) {
    let c = matmulParallel(a, b, numThreads: getNumThreads())
    let center = c[Int(n) / 2][Int(n) / 2]
    resultVal &+= Helper.checksumF64(center)
  }
}

final class Matmul4T: MatmulParallelBase {
  override func name() -> String {
    return "Matmul::T4"
  }

  override func getNumThreads() -> Int {
    return 4
  }
}

final class Matmul8T: MatmulParallelBase {
  override func name() -> String {
    return "Matmul::T8"
  }

  override func getNumThreads() -> Int {
    return 8
  }
}

final class Matmul16T: MatmulParallelBase {
  override func name() -> String {
    return "Matmul::T16"
  }

  override func getNumThreads() -> Int {
    return 16
  }
}
