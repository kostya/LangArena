package benchmarks

import Benchmark

class Words : Benchmark() {
    private val words = configInt("words")
    private val wordLen = configInt("word_len")
    private lateinit var text: String
    private var checksumVal: UInt = 0u

    companion object {
        private val CHARS = "abcdefghijklmnopqrstuvwxyz".toCharArray()
    }

    override fun prepare() {
        text =
            List(words) {
                val len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3
                String(CharArray(len) { CHARS[Helper.nextInt(CHARS.size)] })
            }.joinToString(" ")
    }

    override fun run(iterationId: Int) {
        val frequencies = mutableMapOf<String, Int>()

        for (word in text.split(' ')) {
            if (word.isEmpty()) continue
            frequencies[word] = frequencies.getOrDefault(word, 0) + 1
        }

        var maxWord = ""
        var maxCount = 0

        for ((word, count) in frequencies) {
            if (count > maxCount) {
                maxCount = count
                maxWord = word
            }
        }

        checksumVal += maxCount.toUInt() + Helper.checksum(maxWord) + frequencies.size.toUInt()
    }

    override fun checksum(): UInt = checksumVal

    override fun name(): String = "Etc::Words"
}
