import Foundation
class BufferHashBenchmark: BenchmarkProtocol {
    var data: [UInt8] = []
    private var _result: UInt32 = 0
    private var n: Int = 0
    init() {
        n = iterations
    }
    func prepare() {
        data = (0..<1_000_000).map { _ in 
            UInt8(Helper.nextInt(max: 256))
        }
    }
    func test() -> UInt32 {
        return 0 // Override in subclasses
    }
    func run() {
        for _ in 0..<n {
            _result = (_result &+ test()) & 0xFFFFFFFF
        }
    }
    var result: Int64 {
        return Int64(_result)
    }
}