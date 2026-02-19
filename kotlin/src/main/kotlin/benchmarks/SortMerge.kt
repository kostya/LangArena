package benchmarks

class SortMerge : SortBenchmark() {
    private fun mergeSortInplace(arr: IntArray) {
        val temp = IntArray(arr.size)
        mergeSortHelper(arr, temp, 0, arr.size - 1)
    }

    private fun mergeSortHelper(
        arr: IntArray,
        temp: IntArray,
        left: Int,
        right: Int,
    ) {
        if (left >= right) return

        val mid = (left + right) / 2
        mergeSortHelper(arr, temp, left, mid)
        mergeSortHelper(arr, temp, mid + 1, right)
        merge(arr, temp, left, mid, right)
    }

    private fun merge(
        arr: IntArray,
        temp: IntArray,
        left: Int,
        mid: Int,
        right: Int,
    ) {
        System.arraycopy(arr, left, temp, left, right - left + 1)

        var i = left
        var j = mid + 1
        var k = left

        while (i <= mid && j <= right) {
            if (temp[i] <= temp[j]) {
                arr[k] = temp[i]
                i++
            } else {
                arr[k] = temp[j]
                j++
            }
            k++
        }

        while (i <= mid) {
            arr[k] = temp[i]
            i++
            k++
        }
    }

    override fun test(): IntArray {
        val arr = data.copyOf()
        mergeSortInplace(arr)
        return arr
    }

    override fun name(): String = "SortMerge"
}
