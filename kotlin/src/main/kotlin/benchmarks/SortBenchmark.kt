package benchmarks

import Benchmark

abstract class SortBenchmark : Benchmark() {
    companion object {
        const val ARR_SIZE = 100_000
    }

    protected lateinit var data: IntArray
    private var _result: UInt = 0u
    protected var n: Int = 0

    init {
        n = iterations
    }

    override fun prepare() {
        data = IntArray(ARR_SIZE) { Helper.nextInt(1_000_000) }
    }

    abstract fun test(): IntArray

    private fun checkNElements(arr: IntArray, n: Int): String {
        val step = arr.size / n
        val sb = StringBuilder()
        sb.append('[')
        
        for (index in 0 until arr.size step step) {
            sb.append(index).append(':').append(arr[index]).append(',')
        }
        sb.append(']').append('\n')
        
        return sb.toString()
    }

    override fun run() {
        var verify = checkNElements(data, 10)

        repeat(n - 1) {
            val t = test()
            _result = (_result + t[t.size / 2].toUInt()) and 0xFFFFFFFFu
        }
        
        val arr = test()
        verify += checkNElements(data, 10)
        verify += checkNElements(arr, 10)
        
        _result = (_result + Helper.checksum(verify)) and 0xFFFFFFFFu
    }

    override val result: Long
        get() = _result.toLong()
}