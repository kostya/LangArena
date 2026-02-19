package benchmarks

import Benchmark

abstract class SortBenchmark : Benchmark() {
    protected lateinit var data: IntArray
    protected var resultVal: UInt = 0u
    protected var sizeVal: Long = 0

    override fun prepare() {
        if (sizeVal == 0L) {
            sizeVal = configVal("size")
            data = IntArray(sizeVal.toInt()) { Helper.nextInt(1_000_000) }
        }
    }

    abstract fun test(): IntArray

    override fun run(iterationId: Int) {
        resultVal += data[Helper.nextInt(sizeVal.toInt())].toUInt()
        val t = test()
        resultVal += t[Helper.nextInt(sizeVal.toInt())].toUInt()
    }

    override fun checksum(): UInt = resultVal
}
