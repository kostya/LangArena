import Foundation

final class Words: BenchmarkProtocol {
  private var words: Int64 = 0
  private var wordLen: Int64 = 0
  private var text: String = ""
  private var checksumVal: UInt32 = 0
  private let chars = "abcdefghijklmnopqrstuvwxyz"

  init() {
    words = configValue("words") ?? 0
    wordLen = configValue("word_len") ?? 0
  }

  func prepare() {
    var wordsList: [String] = []
    wordsList.reserveCapacity(Int(words))

    for _ in 0..<Int(words) {
      let len = Helper.nextInt(max: Int(wordLen)) + Helper.nextInt(max: 3) + 3
      var wordChars: [Character] = []
      wordChars.reserveCapacity(len)
      for _ in 0..<len {
        let idx = Helper.nextInt(max: chars.count)
        wordChars.append(chars[chars.index(chars.startIndex, offsetBy: idx)])
      }
      wordsList.append(String(wordChars))
    }

    text = wordsList.joined(separator: " ")
  }

  func run(iterationId: Int) {

    var frequencies = [String: Int]()

    for word in text.split(separator: " ").map(String.init) {
      if word.isEmpty { continue }
      frequencies[word, default: 0] += 1
    }

    var maxWord = ""
    var maxCount = 0

    for (word, count) in frequencies {
      if count > maxCount {
        maxCount = count
        maxWord = word
      }
    }

    let freqSize = UInt32(frequencies.count)
    let wordChecksum = Helper.checksum(maxWord)

    checksumVal &+= UInt32(maxCount) + wordChecksum + freqSize
  }

  var checksum: UInt32 {
    return checksumVal
  }

  func name() -> String {
    return "Etc::Words"
  }
}
