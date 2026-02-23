package benchmarks

class BufferHashCRC32 : BufferHashBenchmark() {
    override fun test(): UInt {
        var crc = 0xFFFFFFFFu

        for (byte in data) {
            crc = crc xor (byte.toUInt() and 0xFFu)
            repeat(8) {
                crc =
                    if ((crc and 1u) != 0u) {
                        (crc shr 1) xor 0xEDB88320u
                    } else {
                        crc shr 1
                    }
            }
        }

        return crc xor 0xFFFFFFFFu
    }

    override fun name(): String = "Hash::CRC32"
}
