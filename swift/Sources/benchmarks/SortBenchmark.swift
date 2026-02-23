import Foundation

class SortBenchmark: BenchmarkProtocol {
  var data: [Int] = []
  private var sizeVal: Int64 = 0
  private var resultVal: UInt32 = 0

  init() {

  }

  func prepare() {
    if sizeVal == 0 {
      sizeVal = configValue("size") ?? 0
      data.reserveCapacity(Int(sizeVal))
      for _ in 0..<Int(sizeVal) {
        data.append(Helper.nextInt(max: 1_000_000))
      }
    }
  }

  func run(iterationId: Int) {
    resultVal &+= UInt32(data[Helper.nextInt(max: Int(sizeVal))])
    let t = test()
    resultVal &+= UInt32(t[Helper.nextInt(max: Int(sizeVal))])
  }

  func test() -> [Int] {
    return []
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return ""
  }
}
