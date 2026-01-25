package benchmarks

class SortMerge : SortBenchmark() {
    override fun test(): IntArray {
        val arr = data.copyOf()
        mergeSortInplace(arr)
        return arr
    }

    private fun mergeSortInplace(arr: IntArray) {
        val temp = IntArray(arr.size)
        mergeSortHelper(arr, temp, 0, arr.size - 1)
    }

    private fun mergeSortHelper(arr: IntArray, temp: IntArray, left: Int, right: Int) {
        if (left >= right) return

        val mid = (left + right) / 2
        mergeSortHelper(arr, temp, left, mid)
        mergeSortHelper(arr, temp, mid + 1, right)
        merge(arr, temp, left, mid, right)
    }

    private fun merge(arr: IntArray, temp: IntArray, left: Int, mid: Int, right: Int) {
        // Копируем обе половины во временный массив
        for (i in left..right) {
            temp[i] = arr[i]
        }

        var i = left      // Индекс левой половины
        var j = mid + 1   // Индекс правой половины
        var k = left      // Индекс в исходном массиве

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

        // Копируем оставшиеся элементы левой половины
        while (i <= mid) {
            arr[k] = temp[i]
            i++
            k++
        }
    }
}