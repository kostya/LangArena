package benchmarks

import Benchmark

abstract class BufferHashBenchmark : Benchmark() {
    protected lateinit var data: ByteArray
    protected var resultVal: UInt = 0u
    protected var sizeVal: Long = 0

    override fun prepare() {
        if (sizeVal == 0L) {
            sizeVal = configVal("size")
            data = ByteArray(sizeVal.toInt()) { Helper.nextInt(256).toByte() }
        }
    }

    abstract fun test(): UInt

    override fun run(iterationId: Int) {
        resultVal += test()
    }

    override fun checksum(): UInt = resultVal
}
