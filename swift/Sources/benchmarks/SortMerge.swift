import Foundation

final class SortMerge: SortBenchmark {
  override init() {
    super.init()
  }

  override var name: String { return "SortMerge" }

  private func mergeSortHelper(_ arr: inout [Int], _ temp: inout [Int], _ left: Int, _ right: Int) {
    if left >= right { return }

    let mid = left + (right - left) / 2

    mergeSortHelper(&arr, &temp, left, mid)
    mergeSortHelper(&arr, &temp, mid + 1, right)

    for i in left...right {
      temp[i] = arr[i]
    }

    var i = left
    var j = mid + 1
    var k = left

    while i <= mid && j <= right {
      if temp[i] <= temp[j] {
        arr[k] = temp[i]
        i += 1
      } else {
        arr[k] = temp[j]
        j += 1
      }
      k += 1
    }

    while i <= mid {
      arr[k] = temp[i]
      i += 1
      k += 1
    }

  }

  private func mergeSort(_ arr: inout [Int]) {
    var temp = [Int](repeating: 0, count: arr.count)
    mergeSortHelper(&arr, &temp, 0, arr.count - 1)
  }

  override func test() -> [Int] {
    var arr = data
    mergeSort(&arr)
    return arr
  }
}
