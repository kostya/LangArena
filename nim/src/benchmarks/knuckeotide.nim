import std/[strutils, sequtils, tables, algorithm, strformat, math]
import ../benchmark
import ../helper
import fasta

type
  Knuckeotide* = ref object of Benchmark
    seq: string
    resultStr: string

proc newKnuckeotide(): Benchmark =
  Knuckeotide()

method name(self: Knuckeotide): string = "CLBG::Knuckeotide"

method prepare(self: Knuckeotide) =
  var fastaInst = cast[Fasta](newFasta())

  fastaInst.n = self.config_val("n")
  fastaInst.prepare()
  fastaInst.run(0)

  let res = fastaInst.get_result()

  var three = false
  self.seq = ""

  for line in res.splitLines():
    if line.startsWith(">THREE"):
      three = true
      continue
    if three:
      self.seq.add(line)

  self.resultStr = ""

proc frequency(seq: string, length: int): (int, Table[string, int]) =
  let n = seq.len - length + 1
  var table = initTable[string, int]()

  for i in 0..<n:
    let sub = seq[i..<i+length]
    table.mgetOrPut(sub, 0).inc()

  result = (n, table)

method sortByFreq(self: Knuckeotide, seq: string, length: int) =
  let (n, table) = frequency(seq, length)

  var pairs: seq[(string, int)]
  for key, value in table.pairs():
    pairs.add((key, value))

  pairs.sort do (a, b: (string, int)) -> int:
    if a[1] == b[1]:
      return cmp(a[0], b[0])
    return cmp(b[1], a[1])

  for (key, value) in pairs:
    let percent = (value.float * 100.0) / n.float
    self.resultStr.add(key.toUpperAscii() & " " & formatFloat(percent,
        ffDecimal, 3) & "\n")

  self.resultStr.add("\n")

method findSeq(self: Knuckeotide, seq: string, s: string) =
  let length = s.len
  let (n, table) = frequency(seq, length)
  let sLower = s.toLowerAscii()
  let count = table.getOrDefault(sLower, 0)

  self.resultStr.add($count & "\t" & s.toUpperAscii() & "\n")

method run(self: Knuckeotide, iteration_id: int) =
  for i in 1..2:
    self.sortByFreq(self.seq, i)

  let searches = @["ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"]
  for s in searches:
    self.findSeq(self.seq, s)

method checksum(self: Knuckeotide): uint32 =
  checksum(self.resultStr)

registerBenchmark("CLBG::Knuckeotide", newKnuckeotide)
