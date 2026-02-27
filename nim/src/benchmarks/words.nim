import std/[math, strutils, tables]
import ../benchmark
import ../helper

type
  Words* = ref object of Benchmark
    words: int64
    wordLen: int64
    text: string
    checksumVal: uint32

proc newWords(): Benchmark =
  Words()

method name(self: Words): string = "Etc::Words"

method prepare(self: Words) =
  self.words = self.config_val("words")
  self.wordLen = self.config_val("word_len")

  let chars = "abcdefghijklmnopqrstuvwxyz"
  var wordsList: seq[string] = @[]

  for i in 0..<self.words.int:
    let len = nextInt(int32(self.wordLen)) + nextInt(3) + 3
    var word = newStringOfCap(len)
    for j in 0..<len:
      let idx = nextInt(chars.len.int32)
      word.add(chars[idx])
    wordsList.add(word)

  self.text = wordsList.join(" ")
  self.checksumVal = 0

method run(self: Words, iteration_id: int) =

  var frequencies = initCountTable[string]()

  for word in self.text.split(' '):
    if word.len == 0: continue
    frequencies.inc(word)

  var maxWord = ""
  var maxCount = 0

  for word, count in frequencies.pairs:
    if count > maxCount:
      maxCount = count
      maxWord = word

  let freqSize = uint32(frequencies.len)
  let wordChecksum = helper.checksum(maxWord)

  self.checksumVal += uint32(maxCount) + wordChecksum + freqSize

method checksum(self: Words): uint32 =
  return self.checksumVal

registerBenchmark("Etc::Words", newWords)
