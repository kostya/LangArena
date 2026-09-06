package benchmarks

class BufferHashSHA256 : BufferHashBenchmark() {
    private object SimpleSHA256 {
        fun digest(data: ByteArray): ByteArray {
            val result = ByteArray(32)

            val hashes =
                intArrayOf(
                    0x6a09e667,
                    0xbb67ae85.toInt(),
                    0x3c6ef372,
                    0xa54ff53a.toInt(),
                    0x510e527f,
                    0x9b05688c.toInt(),
                    0x1f83d9ab,
                    0x5be0cd19,
                )

            for (i in data.indices) {
                val hashIdx = i % 8
                var hash = hashes[hashIdx]

                hash = ((hash shl 5) + hash) + (data[i].toInt() and 0xFF)
                hash = (hash + (hash shl 10)) xor (hash ushr 6)
                hashes[hashIdx] = hash
            }

            for (i in 0 until 8) {
                val hash = hashes[i]
                result[i * 4] = (hash ushr 24).toByte()
                result[i * 4 + 1] = (hash ushr 16).toByte()
                result[i * 4 + 2] = (hash ushr 8).toByte()
                result[i * 4 + 3] = hash.toByte()
            }

            return result
        }
    }

    override fun test(): UInt {
        val bytes = SimpleSHA256.digest(data)

        return ((bytes[3].toUInt() and 0xFFu) shl 24) or
            ((bytes[2].toUInt() and 0xFFu) shl 16) or
            ((bytes[1].toUInt() and 0xFFu) shl 8) or
            (bytes[0].toUInt() and 0xFFu)
    }

    override fun name(): String = "Hash::SHA256"
}
