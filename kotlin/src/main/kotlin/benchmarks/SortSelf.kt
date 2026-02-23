package benchmarks

class SortSelf : SortBenchmark() {
    override fun test(): IntArray {
        val arr = data.copyOf()
        arr.sort()
        return arr
    }

    override fun name(): String = "Sort::Self"
}
