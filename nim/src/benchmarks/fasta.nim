import std/[strutils, strformat, sequtils, algorithm, math, streams]
import ../benchmark
import ../helper

const LINE_LENGTH = 60

type
  Gene = tuple[c: char, prob: float]

  Fasta* = ref object of Benchmark
    n*: int64
    stream: StringStream

proc newFasta*(): Benchmark =
  Fasta(n: config_i64("CLBG::Fasta", "n"))

method name(self: Fasta): string = "CLBG::Fasta"

method prepare(self: Fasta) =
  self.stream = newStringStream()

proc selectRandom(genelist: seq[Gene]): char =
  let r = nextFloat()
  if r < genelist[0].prob:
    return genelist[0].c

  var lo = 0
  var hi = genelist.len - 1

  while hi > lo + 1:
    let i = (hi + lo) div 2
    if r < genelist[i].prob:
      hi = i
    else:
      lo = i

  return genelist[hi].c

proc makeRandomFasta(self: Fasta, id, desc: string,
                    genelist: seq[Gene], nIter: int) =
  self.stream.write(">" & id & " " & desc & "\n")
  var todo = nIter

  while todo > 0:
    let m = if todo < LINE_LENGTH: todo else: LINE_LENGTH
    var buffer = newString(m)

    for i in 0..<m:
      buffer[i] = selectRandom(genelist)

    self.stream.write(buffer)
    self.stream.write("\n")
    todo -= LINE_LENGTH

proc makeRepeatFasta(self: Fasta, id, desc, s: string, nIter: int) =
  self.stream.write(">" & id & " " & desc & "\n")
  var todo = nIter
  var k = 0
  let kn = s.len

  while todo > 0:
    let m = if todo < LINE_LENGTH: todo else: LINE_LENGTH

    if m >= kn - k:
      self.stream.write(s[k..^1])
      var remaining = m - (kn - k)
      k = 0

      while remaining >= kn:
        self.stream.write(s)
        remaining -= kn

      if remaining > 0:
        self.stream.write(s[0..<remaining])
        k = remaining
    else:
      self.stream.write(s[k..<k+m])
      k += m

    self.stream.write("\n")
    todo -= LINE_LENGTH

const IUB = @[
  ('a', 0.27), ('c', 0.39), ('g', 0.51), ('t', 0.78),
  ('B', 0.8), ('D', 0.8200000000000001),
  ('H', 0.8400000000000001), ('K', 0.8600000000000001),
  ('M', 0.8800000000000001), ('N', 0.9000000000000001),
  ('R', 0.9200000000000002), ('S', 0.9400000000000002),
  ('V', 0.9600000000000002), ('W', 0.9800000000000002),
  ('Y', 1.0000000000000002)
]

const HOMO = @[
  ('a', 0.302954942668), ('c', 0.5009432431601),
  ('g', 0.6984905497992), ('t', 1.0)
]

const ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

method run(self: Fasta, iteration_id: int) =
  self.makeRepeatFasta("ONE", "Homo sapiens alu", ALU, int(self.n * 2))
  self.makeRandomFasta("TWO", "IUB ambiguity codes", IUB, int(self.n * 3))
  self.makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, int(self.n * 5))

method checksum(self: Fasta): uint32 =
  checksum(self.stream.data)

proc get_result*(self: Fasta): string =
  self.stream.data

registerBenchmark("CLBG::Fasta", newFasta)
