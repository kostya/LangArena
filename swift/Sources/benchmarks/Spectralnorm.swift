import Foundation
final class Spectralnorm: BenchmarkProtocol {
    private var n: Int = 0
    private var resultValue: Int64 = 0
    init() {
        n = iterations
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
    func run() {
        var u = [Double](repeating: 1.0, count: n)
        var v = [Double](repeating: 1.0, count: n)
        for _ in 0..<10 {
            v = evalAtATimesU(u)
            u = evalAtATimesU(v)
        }
        var vBv = 0.0
        var vv = 0.0
        for i in 0..<n {
            vBv += u[i] * v[i]
            vv += v[i] * v[i]
        }
        let resultDouble = sqrt(vBv / vv)
        resultValue = Int64(Helper.checksumF64(resultDouble))
    }
    var result: Int64 {
        return resultValue
    }
    func prepare() {}
}