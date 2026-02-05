import std/[strutils, sequtils, algorithm]
import ../benchmark
import ../helper
import fasta

type
  Revcomp* = ref object of Benchmark
    input: string
    checksumVal: uint32

proc newRevcomp(): Benchmark =
  Revcomp()

method name(self: Revcomp): string = "Revcomp"

method prepare(self: Revcomp) =
  var fasta = Fasta()
  fasta.n = self.config_val("n")
  fasta.prepare()
  fasta.run(0)
  let fasta_result = fasta.get_result()

  var seq = ""
  for line in fasta_result.splitLines():
    if line.startsWith('>'):
      seq.add("\n---\n")
    else:
      seq.add(line)

  self.input = seq
  self.checksumVal = 0

const fromChars = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
const toChars = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

proc revcomp(seq: string): string =

  var reversed = seq
  reversed.reverse()

  var lookup: array[256, char]
  for i in 0..255:
    lookup[i] = chr(i)
  for i in 0..<fromChars.len:
    lookup[ord(fromChars[i])] = toChars[i]

  for i in 0..<reversed.len:
    reversed[i] = lookup[ord(reversed[i])]

  result = ""
  let totalLen = reversed.len + (reversed.len div 60) + 1
  result = newStringOfCap(totalLen)

  var i = 0
  while i < reversed.len:
    let endIdx = min(i + 60, reversed.len)
    result.add(reversed[i..<endIdx])
    result.add("\n")
    i += 60

method run(self: Revcomp, iteration_id: int) =
  let resultStr = revcomp(self.input)
  self.checksumVal = self.checksumVal + checksum(resultStr)

method checksum(self: Revcomp): uint32 =
  self.checksumVal

registerBenchmark("Revcomp", newRevcomp)