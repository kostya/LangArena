import std/[strutils, strformat, sequtils, algorithm, math, tables, re]
import ../benchmark
import ../helper
import fasta

type
  RegexDna* = ref object of Benchmark
    seqData: string
    ilen: int
    clen: int
    resultStr: string
    compiledPatterns: seq[Regex]

proc newRegexDna(): Benchmark =
  RegexDna()

method name(self: RegexDna): string = "CLBG::RegexDna"

const patternStrings = [
  "agggtaaa|tttaccct",
  "[cgt]gggtaaa|tttaccc[acg]",
  "a[act]ggtaaa|tttacc[agt]t",
  "ag[act]gtaaa|tttac[agt]ct",
  "agg[act]taaa|ttta[agt]cct",
  "aggg[acg]aaa|ttt[cgt]ccct",
  "agggt[cgt]aa|tt[acg]accct",
  "agggta[cgt]a|t[acg]taccct",
  "agggtaa[cgt]|[acg]ttaccct"
]

method prepare(self: RegexDna) =

  let fastaInst = cast[Fasta](newFasta())
  fastaInst.n = self.config_val("n")
  fastaInst.prepare()
  fastaInst.run(0)
  let res = fastaInst.get_result()

  self.seqData = ""
  self.ilen = 0

  for line in res.splitLines():
    self.ilen += line.len + 1
    if line.len > 0 and line[0] != '>':
      self.seqData.add(line)

  self.ilen -= 1
  self.clen = self.seqData.len

  self.compiledPatterns = newSeq[Regex]()
  for patternStr in patternStrings:
    try:
      let regex = re(patternStr)
      self.compiledPatterns.add(regex)
    except:
      echo "Error compiling regex: ", patternStr

  self.resultStr = ""

method run(self: RegexDna, iteration_id: int) =
  for i, pattern in self.compiledPatterns.pairs:
    var count = 0
    var pos = 0

    while pos < self.seqData.len:
      let (first, last) = self.seqData.findBounds(pattern, pos)
      if first < 0:
        break
      inc count
      pos = last + 1

    self.resultStr.add(patternStrings[i] & " " & $count & "\n")

  const replacements = [
    ('B', "(c|g|t)"),
    ('D', "(a|g|t)"),
    ('H', "(a|c|t)"),
    ('K', "(g|t)"),
    ('M', "(a|c)"),
    ('N', "(a|c|g|t)"),
    ('R', "(a|g)"),
    ('S', "(c|t)"),
    ('V', "(a|c|g)"),
    ('W', "(a|t)"),
    ('Y', "(c|t)")
  ]

  var seq2 = newStringOfCap(self.seqData.len * 9)

  for c in self.seqData:
    var replaced = false
    for (fromChar, toStr) in replacements:
      if c == fromChar:
        seq2.add(toStr)
        replaced = true
        break

    if not replaced:
      seq2.add(c)

  self.resultStr.add("\n")
  self.resultStr.add($self.ilen & "\n")
  self.resultStr.add($self.clen & "\n")
  self.resultStr.add($seq2.len & "\n")

method checksum(self: RegexDna): uint32 =
  checksum(self.resultStr)

registerBenchmark("CLBG::RegexDna", newRegexDna)
