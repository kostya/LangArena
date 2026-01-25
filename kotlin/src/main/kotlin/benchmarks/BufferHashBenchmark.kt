package benchmarks

import Benchmark

abstract class BufferHashBenchmark : Benchmark() {
    protected lateinit var data: ByteArray
    private var _result: UInt = 0u
    private var n: Int = 0

    init {
        n = iterations
    }

    override fun prepare() {
        // Генерируем случайные данные для хэширования
        data = ByteArray(1_000_000) { Helper.nextInt(256).toByte() }
    }

    abstract fun test(): UInt

    override fun run() {
        repeat(n) {
            _result = (_result + test()) and 0xFFFFFFFFu
        }
    }

    override val result: Long
        get() = _result.toLong()
}