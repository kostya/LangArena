package benchmarks

class SortQuick : SortBenchmark() {
    private fun quickSort(
        arr: IntArray,
        low: Int,
        high: Int,
    ) {
        if (low >= high) return

        val pivot = arr[(low + high) / 2]
        var i = low
        var j = high

        while (i <= j) {
            while (arr[i] < pivot) i++
            while (arr[j] > pivot) j--
            if (i <= j) {
                val temp = arr[i]
                arr[i] = arr[j]
                arr[j] = temp
                i++
                j--
            }
        }

        quickSort(arr, low, j)
        quickSort(arr, i, high)
    }

    override fun test(): IntArray {
        val arr = data.copyOf()
        quickSort(arr, 0, arr.size - 1)
        return arr
    }

    override fun name(): String = "SortQuick"
}
