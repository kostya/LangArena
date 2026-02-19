import Foundation

class BufferHashBenchmark: BenchmarkProtocol {
  var data: [UInt8] = []
  private var sizeVal: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {

  }

  func prepare() {
    if sizeVal == 0 {
      sizeVal = configValue("size") ?? 0
      data.reserveCapacity(Int(sizeVal))
      for _ in 0..<Int(sizeVal) {
        data.append(UInt8(Helper.nextInt(max: 256)))
      }
    }
  }

  func test() -> UInt32 {
    return 0
  }

  func run(iterationId: Int) {
    resultVal &+= test()
  }

  var checksum: UInt32 {
    return resultVal
  }

  var name: String { return "BufferHashBenchmark" }
}
