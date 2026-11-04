from helper import Helper
from benchmark import Benchmark, Config


def _quick_sort(mut arr: List[Int], low: Int, high: Int):
    if low >= high:
        return

    var pivot = arr[(low + high) // 2]
    var i = low
    var j = high

    while i <= j:
        while arr[i] < pivot:
            i += 1
        while arr[j] > pivot:
            j -= 1
        if i <= j:
            arr.swap_elements(i, j)
            i += 1
            j -= 1

    _quick_sort(arr, low, j)
    _quick_sort(arr, i, high)


def _merge_sort(mut arr: List[Int], mut temp: List[Int], left: Int, right: Int):
    if left >= right:
        return

    var mid = (left + right) // 2
    _merge_sort(arr, temp, left, mid)
    _merge_sort(arr, temp, mid + 1, right)
    _merge(arr, temp, left, mid, right)


def _merge(
    mut arr: List[Int], mut temp: List[Int], left: Int, mid: Int, right: Int
):
    temp[left : right + 1].copy_from(arr[left : right + 1])

    var i = left
    var j = mid + 1
    var k = left

    while i <= mid and j <= right:
        if temp[i] <= temp[j]:
            arr[k] = temp[i]
            i += 1
        else:
            arr[k] = temp[j]
            j += 1
        k += 1

    while i <= mid:
        arr[k] = temp[i]
        i += 1
        k += 1


struct SortQuick(Benchmark):
    var size: Int
    var data: List[Int]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Sort::Quick", "size")
        self.data = List[Int]()
        self.result = 0

    def class_name(self) -> String:
        return "Sort::Quick"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = List[Int]()
        for _ in range(self.size):
            self.data.append(helper.next_int(1000000))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.result += UInt32(self.data[helper.next_int(self.size)])
        var sorted = self.data.copy()
        _quick_sort(sorted, 0, len(sorted) - 1)
        self.result += UInt32(sorted[helper.next_int(self.size)])

    def checksum(mut self) -> UInt32:
        return self.result


struct SortMerge(Benchmark):
    var size: Int
    var data: List[Int]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Sort::Merge", "size")
        self.data = List[Int]()
        self.result = 0

    def class_name(self) -> String:
        return "Sort::Merge"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = List[Int]()
        for _ in range(self.size):
            self.data.append(helper.next_int(1000000))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.result += UInt32(self.data[helper.next_int(self.size)])
        var sorted = self.data.copy()
        var temp = List[Int](length=len(sorted), fill=0)
        _merge_sort(sorted, temp, 0, len(sorted) - 1)
        self.result += UInt32(sorted[helper.next_int(self.size)])

    def checksum(mut self) -> UInt32:
        return self.result


struct SortSelf(Benchmark):
    var size: Int
    var data: List[Int]
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Sort::Self", "size")
        self.data = List[Int]()
        self.result = 0

    def class_name(self) -> String:
        return "Sort::Self"

    def prepare(mut self, mut helper: Helper) raises:
        self.data = List[Int]()
        for _ in range(self.size):
            self.data.append(helper.next_int(1000000))

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.result += UInt32(self.data[helper.next_int(self.size)])
        var sorted = self.data.copy()

        sort(Span(sorted))

        self.result += UInt32(sorted[helper.next_int(self.size)])

    def checksum(mut self) -> UInt32:
        return self.result
