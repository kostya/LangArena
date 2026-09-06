package benchmarks

import Benchmark

abstract class SortBenchmark : Benchmark() {
    protected val sizeVal = configInt("size")
    protected lateinit var data: IntArray
    protected var resultVal: UInt = 0u

    override fun prepare() {
        data = IntArray(sizeVal) { Helper.nextInt(1_000_000) }
    }

    abstract fun test(): IntArray

    override fun run(iterationId: Int) {
        resultVal += data[Helper.nextInt(sizeVal)].toUInt()
        val t = test()
        resultVal += t[Helper.nextInt(sizeVal)].toUInt()
    }

    override fun checksum(): UInt = resultVal
}
