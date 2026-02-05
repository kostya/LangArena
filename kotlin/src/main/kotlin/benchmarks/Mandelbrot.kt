package benchmarks

import Benchmark

class Mandelbrot : Benchmark() {
    private var w: Int = 0
    private var h: Int = 0
    private lateinit var result: java.io.ByteArrayOutputStream

    companion object {
        private const val ITER = 50
        private const val LIMIT = 2.0
    }

    init {
        w = configVal("w").toInt()
        h = configVal("h").toInt()
    }

    override fun prepare() {
        result = java.io.ByteArrayOutputStream()
    }

    override fun run(iterationId: Int) {        

        result.write("P4\n$w $h\n".toByteArray())

        var bitNum = 0
        var byteAcc = 0

        for (y in 0 until h) {
            for (x in 0 until w) {
                var zr = 0.0
                var zi = 0.0
                var tr = 0.0
                var ti = 0.0
                val cr = 2.0 * x / w.toDouble() - 1.5
                val ci = 2.0 * y / h.toDouble() - 1.0

                var i = 0
                while (i < ITER && tr + ti <= LIMIT * LIMIT) {
                    zi = 2.0 * zr * zi + ci
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1
                }

                byteAcc = (byteAcc shl 1) and 0xFF
                if (tr + ti <= LIMIT * LIMIT) {
                    byteAcc = byteAcc or 0x01
                }
                bitNum += 1

                if (bitNum == 8) {
                    result.write(byteAcc)
                    byteAcc = 0
                    bitNum = 0
                } else if (x == w - 1) {

                    if (bitNum > 0) {
                        byteAcc = (byteAcc shl (8 - bitNum)) and 0xFF
                        result.write(byteAcc)
                    }
                    byteAcc = 0
                    bitNum = 0
                }
            }
        }
    }

    override fun checksum(): UInt {
        val bytes = result.toByteArray()
        val checksum = Helper.checksum(bytes)        
        return checksum
    }

    override fun name(): String = "Mandelbrot"
}