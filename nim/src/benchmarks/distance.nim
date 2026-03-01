import std/[strformat, tables, math]
import ../benchmark
import ../helper

type
  StringPair = tuple[s1: string, s2: string]

proc generatePairStrings(n: int, m: int): seq[StringPair] =
  result = newSeq[StringPair](n)
  let chars = "abcdefghij"

  for i in 0..<n:
    let len1 = nextInt(m.int32) + 4
    let len2 = nextInt(m.int32) + 4

    var str1 = newString(len1)
    var str2 = newString(len2)

    for j in 0..<len1:
      str1[j] = chars[nextInt(10)]
    for j in 0..<len2:
      str2[j] = chars[nextInt(10)]

    result[i] = (str1, str2)

type
  Jaro* = ref object of Benchmark
    count: int
    size: int
    pairs: seq[StringPair]
    resultVal: uint32

proc newJaro(): Benchmark =
  Jaro()

method name(self: Jaro): string = "Distance::Jaro"

method prepare(self: Jaro) =
  self.count = int(self.config_val("count"))
  self.size = int(self.config_val("size"))
  self.pairs = generatePairStrings(self.count, self.size)
  self.resultVal = 0'u32

proc jaro(s1: string, s2: string): float64 =

  let bytes1 = cast[seq[byte]](s1)
  let bytes2 = cast[seq[byte]](s2)

  let len1 = bytes1.len
  let len2 = bytes2.len

  if len1 == 0 or len2 == 0:
    return 0.0

  var matchDist = max(len1, len2) div 2 - 1
  if matchDist < 0:
    matchDist = 0

  var s1Matches = newSeq[bool](len1)
  var s2Matches = newSeq[bool](len2)

  var matches = 0
  for i in 0..<len1:
    let start = max(0, i - matchDist)
    let finish = min(len2 - 1, i + matchDist)

    for j in start..finish:
      if not s2Matches[j] and bytes1[i] == bytes2[j]:
        s1Matches[i] = true
        s2Matches[j] = true
        matches += 1
        break

  if matches == 0:
    return 0.0

  var transpositions = 0
  var k = 0
  for i in 0..<len1:
    if s1Matches[i]:
      while k < len2 and not s2Matches[k]:
        k += 1
      if k < len2:
        if bytes1[i] != bytes2[k]:
          transpositions += 1
        k += 1

  transpositions = transpositions div 2

  let m = matches.float64
  return (m/len1.float64 + m/len2.float64 + (m - transpositions.float64)/m) / 3.0

method run(self: Jaro, iteration_id: int) =
  for (s1, s2) in self.pairs:
    self.resultVal += uint32(jaro(s1, s2) * 1000)

method checksum(self: Jaro): uint32 =
  return self.resultVal

type
  NGram* = ref object of Benchmark
    count: int
    size: int
    pairs: seq[StringPair]
    resultVal: uint32
    n: int

proc newNGram(): Benchmark =
  NGram(n: 4)

method name(self: NGram): string = "Distance::NGram"

method prepare(self: NGram) =
  self.count = int(self.config_val("count"))
  self.size = int(self.config_val("size"))
  self.pairs = generatePairStrings(self.count, self.size)
  self.resultVal = 0'u32

proc ngram(self: NGram, s1: string, s2: string): float64 =

  let bytes1 = cast[seq[byte]](s1)
  let bytes2 = cast[seq[byte]](s2)

  if bytes1.len < self.n or bytes2.len < self.n:
    return 0.0

  var grams1 = initTable[uint32, int]()

  for i in 0..(bytes1.len - self.n):
    let gram = (uint32(bytes1[i]) shl 24) or
               (uint32(bytes1[i+1]) shl 16) or
               (uint32(bytes1[i+2]) shl 8) or
                uint32(bytes1[i+3])

    discard grams1.mgetOrPut(gram, 0) + 1

    grams1.withValue(gram, val):
      val[] += 1
    do:
      grams1[gram] = 1

  var grams2 = initTable[uint32, int]()
  var intersection = 0

  for i in 0..(bytes2.len - self.n):
    let gram = (uint32(bytes2[i]) shl 24) or
               (uint32(bytes2[i+1]) shl 16) or
               (uint32(bytes2[i+2]) shl 8) or
                uint32(bytes2[i+3])

    grams2.withValue(gram, val):
      val[] += 1
    do:
      grams2[gram] = 1

    let count1 = grams1.getOrDefault(gram, 0)
    if count1 > 0 and grams2[gram] <= count1:
      intersection += 1

  let total = grams1.len + grams2.len
  return if total > 0: intersection.float64 / total.float64 else: 0.0

method run(self: NGram, iteration_id: int) =
  for (s1, s2) in self.pairs:
    self.resultVal += uint32(self.ngram(s1, s2) * 1000)

method checksum(self: NGram): uint32 =
  return self.resultVal

registerBenchmark("Distance::Jaro", newJaro)
registerBenchmark("Distance::NGram", newNGram)
