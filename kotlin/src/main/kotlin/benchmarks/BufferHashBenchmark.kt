package benchmarks

import Benchmark

abstract class BufferHashBenchmark : Benchmark() {
    protected val sizeVal = configInt("size")
    protected lateinit var data: ByteArray
    protected var resultVal: UInt = 0u

    override fun prepare() {
        data = ByteArray(sizeVal) { Helper.nextInt(256).toByte() }
    }

    abstract fun test(): UInt

    override fun run(iterationId: Int) {
        resultVal += test()
    }

    override fun checksum(): UInt = resultVal
}
