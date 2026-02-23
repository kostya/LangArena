import ../benchmark
import ../helper
import sort_common

type
  SortMerge* = ref object of SortBenchmark

proc newSortMerge(): Benchmark =
  SortMerge()

method name(self: SortMerge): string = "Sort::Merge"

proc mergeSortInplace(arr: var seq[int32]) =
  var temp = newSeq[int32](arr.len)

  proc mergeSortHelper(arr: var seq[int32], temp: var seq[int32], left, right: int) =
    if left >= right:
      return

    let mid = (left + right) div 2
    mergeSortHelper(arr, temp, left, mid)
    mergeSortHelper(arr, temp, mid + 1, right)

    for i in left..right:
      temp[i] = arr[i]

    var i = left
    var j = mid + 1
    var k = left

    while i <= mid and j <= right:
      if temp[i] <= temp[j]:
        arr[k] = temp[i]
        inc i
      else:
        arr[k] = temp[j]
        inc j
      inc k

    while i <= mid:
      arr[k] = temp[i]
      inc i
      inc k

    while j <= right:
      arr[k] = temp[j]
      inc j
      inc k

  mergeSortHelper(arr, temp, 0, arr.len - 1)

method test(self: SortMerge): seq[int32] =
  var arr = self.data
  mergeSortInplace(arr)
  arr

registerBenchmark("Sort::Merge", newSortMerge)
