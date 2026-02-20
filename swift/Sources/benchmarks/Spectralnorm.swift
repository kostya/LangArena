import Foundation

final class Spectralnorm: BenchmarkProtocol {
  private var sizeVal: Int64 = 0
  private var u: [Double] = []
  private var v: [Double] = []

  init() {
    sizeVal = configValue("size") ?? 0
    u = [Double](repeating: 1.0, count: Int(sizeVal))
    v = [Double](repeating: 1.0, count: Int(sizeVal))
  }

  private func evalA(_ i: Int, _ j: Int) -> Double {
    return 1.0 / ((Double(i + j) * Double(i + j + 1)) / 2.0 + Double(i) + 1.0)
  }

  private func evalATimesU(_ u: [Double]) -> [Double] {
    return (0..<u.count).map { i in
      var v = 0.0
      for j in 0..<u.count {
        v += evalA(i, j) * u[j]
      }
      return v
    }
  }

  private func evalAtTimesU(_ u: [Double]) -> [Double] {
    return (0..<u.count).map { i in
      var v = 0.0
      for j in 0..<u.count {
        v += evalA(j, i) * u[j]
      }
      return v
    }
  }

  private func evalAtATimesU(_ u: [Double]) -> [Double] {
    return evalAtTimesU(evalATimesU(u))
  }

  func run(iterationId: Int) {
    v = evalAtATimesU(u)
    u = evalAtATimesU(v)
  }

  var checksum: UInt32 {
    var vBv = 0.0
    var vv = 0.0
    for i in 0..<Int(sizeVal) {
      vBv += u[i] * v[i]
      vv += v[i] * v[i]
    }
    return Helper.checksumF64(sqrt(vBv / vv))
  }

  func prepare() {}
}
