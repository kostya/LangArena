import Foundation

final class SortMerge: SortBenchmark {
    override init() {
        super.init()
    }

    override var name: String { return "SortMerge" }

    private func mergeSort(_ arr: inout [Int], left: Int, right: Int) {
        if left >= right { return }

        let mid = (left + right) / 2
        mergeSort(&arr, left: left, right: mid)
        mergeSort(&arr, left: mid + 1, right: right)
        merge(&arr, left: left, mid: mid, right: right)
    }

    private func merge(_ arr: inout [Int], left: Int, mid: Int, right: Int) {
        let leftArray = Array(arr[left...mid])
        let rightArray = Array(arr[(mid + 1)...right])

        var i = 0
        var j = 0
        var k = left

        while i < leftArray.count && j < rightArray.count {
            if leftArray[i] <= rightArray[j] {
                arr[k] = leftArray[i]
                i += 1
            } else {
                arr[k] = rightArray[j]
                j += 1
            }
            k += 1
        }

        while i < leftArray.count {
            arr[k] = leftArray[i]
            i += 1
            k += 1
        }

        while j < rightArray.count {
            arr[k] = rightArray[j]
            j += 1
            k += 1
        }
    }

    override func test() -> [Int] {
        var arr = data
        mergeSort(&arr, left: 0, right: arr.count - 1)
        return arr
    }
}