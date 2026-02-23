import Foundation

final class SortQuick: SortBenchmark {
  override init() {
    super.init()
  }

  private func quickSort(_ arr: inout [Int], low: Int, high: Int) {
    if low >= high { return }

    let pivot = arr[(low + high) / 2]
    var i = low
    var j = high

    while i <= j {
      while arr[i] < pivot { i += 1 }
      while arr[j] > pivot { j -= 1 }
      if i <= j {
        arr.swapAt(i, j)
        i += 1
        j -= 1
      }
    }

    quickSort(&arr, low: low, high: j)
    quickSort(&arr, low: i, high: high)
  }

  override func test() -> [Int] {
    var arr = data
    quickSort(&arr, low: 0, high: arr.count - 1)
    return arr
  }

  override func name() -> String {
    return "Sort::Quick"
  }
}
