package benchmarks

import Benchmark

class Words : Benchmark() {
    private var words: Int = 0
    private var wordLen: Int = 0
    private lateinit var text: String
    private var checksumVal: UInt = 0u

    companion object {
        private val CHARS = "abcdefghijklmnopqrstuvwxyz".toCharArray()
    }

    init {
        words = configVal("words").toInt()
        wordLen = configVal("word_len").toInt()
    }

    override fun prepare() {
        val wordsList = mutableListOf<String>()

        for (i in 0 until words) {
            val len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3
            val wordChars = CharArray(len)
            for (j in 0 until len) {
                val idx = Helper.nextInt(CHARS.size)
                wordChars[j] = CHARS[idx]
            }
            wordsList.add(String(wordChars))
        }

        text = wordsList.joinToString(" ")
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

        val freqSize = frequencies.size.toUInt()
        val wordChecksum = Helper.checksum(maxWord)

        checksumVal += maxCount.toUInt() + wordChecksum + freqSize
    }

    override fun checksum(): UInt = checksumVal

    override fun name(): String = "Etc::Words"
}
