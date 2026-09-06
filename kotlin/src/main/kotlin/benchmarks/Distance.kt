package benchmarks

import Benchmark
import Helper
import java.nio.charset.StandardCharsets

object Distance {
    private const val ALPHABET = "abcdefghij"

    data class StringPair(
        val s1: String,
        val s2: String,
    )

    fun generatePairStrings(
        n: Int,
        m: Int,
    ): Array<StringPair> {
        return Array(n) {
            val len1 = Helper.nextInt(m) + 4
            val len2 = Helper.nextInt(m) + 4

            val str1 =
                buildString {
                    repeat(len1) {
                        append(ALPHABET[Helper.nextInt(10)])
                    }
                }
            val str2 =
                buildString {
                    repeat(len2) {
                        append(ALPHABET[Helper.nextInt(10)])
                    }
                }

            StringPair(str1, str2)
        }
    }

    class Jaro : Benchmark() {
        private val count = configInt("count")
        private val size = configInt("size")
        private lateinit var pairs: Array<StringPair>
        private var resultVal: UInt = 0u

        override fun prepare() {
            pairs = generatePairStrings(count, size)
            resultVal = 0u
        }

        private fun jaro(
            s1: String,
            s2: String,
        ): Double {
            val bytes1 = s1.toByteArray(StandardCharsets.US_ASCII)
            val bytes2 = s2.toByteArray(StandardCharsets.US_ASCII)

            val len1 = bytes1.size
            val len2 = bytes2.size

            if (len1 == 0 || len2 == 0) return 0.0

            val matchDist = (maxOf(len1, len2) / 2 - 1).coerceAtLeast(0)

            val s1Matches = BooleanArray(len1)
            val s2Matches = BooleanArray(len2)

            var matches = 0
            for (i in 0 until len1) {
                val start = maxOf(0, i - matchDist)
                val end = minOf(len2 - 1, i + matchDist)

                for (j in start..end) {
                    if (!s2Matches[j] && bytes1[i] == bytes2[j]) {
                        s1Matches[i] = true
                        s2Matches[j] = true
                        matches++
                        break
                    }
                }
            }

            if (matches == 0) return 0.0

            var transpositions = 0
            var k = 0
            for (i in 0 until len1) {
                if (s1Matches[i]) {
                    while (k < len2 && !s2Matches[k]) {
                        k++
                    }
                    if (k < len2) {
                        if (bytes1[i] != bytes2[k]) {
                            transpositions++
                        }
                        k++
                    }
                }
            }
            transpositions /= 2

            val m = matches.toDouble()
            return (m / len1 + m / len2 + (m - transpositions) / m) / 3.0
        }

        override fun run(iterationId: Int) {
            for (pair in pairs) {
                resultVal += (jaro(pair.s1, pair.s2) * 1000).toUInt()
            }
        }

        override fun checksum(): UInt = resultVal

        override fun name(): String = "Distance::Jaro"
    }

    class NGram : Benchmark() {
        private val count = configInt("count")
        private val size = configInt("size")
        private lateinit var pairs: Array<StringPair>
        private var resultVal: UInt = 0u

        private companion object {
            const val N = 4
        }

        override fun prepare() {
            pairs = generatePairStrings(count, size)
            resultVal = 0u
        }

        private fun ngram(
            s1: String,
            s2: String,
        ): Double {
            val bytes1 = s1.toByteArray(StandardCharsets.US_ASCII)
            val bytes2 = s2.toByteArray(StandardCharsets.US_ASCII)

            if (bytes1.size < N || bytes2.size < N) return 0.0

            val grams1 = HashMap<Int, Int>(bytes1.size)

            for (i in 0..bytes1.size - N) {
                val gram =
                    ((bytes1[i].toInt() and 0xFF) shl 24) or
                        ((bytes1[i + 1].toInt() and 0xFF) shl 16) or
                        ((bytes1[i + 2].toInt() and 0xFF) shl 8) or
                        (bytes1[i + 3].toInt() and 0xFF)

                grams1.merge(gram, 1) { old, _ -> old + 1 }
            }

            val grams2 = HashMap<Int, Int>(bytes2.size)
            var intersection = 0

            for (i in 0..bytes2.size - N) {
                val gram =
                    ((bytes2[i].toInt() and 0xFF) shl 24) or
                        ((bytes2[i + 1].toInt() and 0xFF) shl 16) or
                        ((bytes2[i + 2].toInt() and 0xFF) shl 8) or
                        (bytes2[i + 3].toInt() and 0xFF)

                val count2 = (grams2[gram] ?: 0) + 1
                grams2[gram] = count2

                val count1 = grams1[gram]
                if (count1 != null && count2 <= count1) {
                    intersection++
                }
            }

            val total = grams1.size + grams2.size
            return if (total > 0) intersection.toDouble() / total else 0.0
        }

        override fun run(iterationId: Int) {
            for (pair in pairs) {
                resultVal += (ngram(pair.s1, pair.s2) * 1000).toUInt()
            }
        }

        override fun checksum(): UInt = resultVal

        override fun name(): String = "Distance::NGram"
    }
}
