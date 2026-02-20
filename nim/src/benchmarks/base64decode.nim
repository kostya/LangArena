import std/[base64, strutils]
import ../benchmark
import ../helper

type
  Base64Decode* = ref object of Benchmark
    str2: string
    str3: string
    resultVal: uint32

proc newBase64Decode(): Benchmark =
  Base64Decode()

method name(self: Base64Decode): string = "Base64Decode"

method prepare(self: Base64Decode) =
  let n = self.config_val("size")
  let str = repeat('a', n.int)

  self.str2 = encode(str)

  try:
    self.str3 = decode(self.str2)
  except Exception:
    self.str3 = ""

  self.resultVal = 0

method run(self: Base64Decode, iteration_id: int) =
  try:
    self.str3 = decode(self.str2)
    self.resultVal = self.resultVal + uint32(self.str3.len)
  except Exception:
    discard

method checksum(self: Base64Decode): uint32 =
  var ss = "decode "
  if self.str2.len > 4:
    ss.add(self.str2[0..3] & "...")
  else:
    ss.add(self.str2)

  ss.add(" to ")

  if self.str3.len > 4:
    ss.add(self.str3[0..3] & "...")
  else:
    ss.add(self.str3)

  ss.add(": " & $self.resultVal)
  checksum(ss)

registerBenchmark("Base64Decode", newBase64Decode)
