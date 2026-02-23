import std/[algorithm]
import ../benchmark
import ../helper
import sort_common

type
  SortSelf* = ref object of SortBenchmark

proc newSortSelf(): Benchmark =
  SortSelf()

method name(self: SortSelf): string = "Sort::Self"

method test(self: SortSelf): seq[int32] =
  var arr = self.data
  arr.sort(system.cmp[int32])
  arr

registerBenchmark("Sort::Self", newSortSelf)
