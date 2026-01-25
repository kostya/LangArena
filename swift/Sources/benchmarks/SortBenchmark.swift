import Foundation
class SortBenchmark: BenchmarkProtocol {
    private static let ARR_SIZE = 100_000
    var data: [Int] = []
    private var _result: UInt32 = 0
    var n: Int = 0
    init() {
        n = iterations
    }
    func prepare() {
        data = (0..<SortBenchmark.ARR_SIZE).map { _ in 
            Helper.nextInt(max: 1_000_000)
        }
    }
    func test() -> [Int] {
        return [] // Override in subclasses
    }
    private func checkNElements(_ arr: [Int], _ n: Int) -> String {
        let step = arr.count / n
        var result = "["
        for index in stride(from: 0, to: arr.count, by: step) {
            result += "\(index):\(arr[index]),"
        }
        result += "]\n"
        return result
    }
    func run() {
        var verify = checkNElements(data, 10)
        for _ in 0..<(n - 1) {
            let t = test()
            _result = (_result &+ UInt32(t[t.count / 2])) & 0xFFFFFFFF
        }
        let arr = test()
        verify += checkNElements(data, 10)
        verify += checkNElements(arr, 10)
        _result = (_result &+ Helper.checksum(verify)) & 0xFFFFFFFF
    }
    var result: Int64 {
        return Int64(_result)
    }
}