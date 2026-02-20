import ../benchmark
import ../helper
import sort_common

type
  SortQuick* = ref object of SortBenchmark

proc newSortQuick(): Benchmark =
  SortQuick()

method name(self: SortQuick): string = "SortQuick"

proc quickSort(arr: var seq[int32], low, high: int) =
  if low >= high:
    return

  let pivot = arr[(low + high) div 2]
  var i = low
  var j = high

  while i <= j:
    while arr[i] < pivot:
      inc i
    while arr[j] > pivot:
      dec j
    if i <= j:
      swap(arr[i], arr[j])
      inc i
      dec j

  if j > low:
    quickSort(arr, low, j)
  if i < high:
    quickSort(arr, i, high)

method test(self: SortQuick): seq[int32] =
  var arr = self.data
  if arr.len > 0:
    quickSort(arr, 0, arr.len - 1)
  arr

registerBenchmark("SortQuick", newSortQuick)
