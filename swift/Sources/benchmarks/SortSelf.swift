import Foundation

final class SortSelf: SortBenchmark {
  override init() {
    super.init()
  }

  override func test() -> [Int] {
    return data.sorted()
  }

  override func name() -> String {
    return "Sort::Self"
  }
}
