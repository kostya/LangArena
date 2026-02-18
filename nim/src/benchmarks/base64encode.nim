import std/[base64, strutils]
import ../benchmark
import ../helper

type
  Base64Encode* = ref object of Benchmark
    str: string
    str2: string
    resultVal: uint32

proc newBase64Encode(): Benchmark =
  Base64Encode()

method name(self: Base64Encode): string = "Base64Encode"

method prepare(self: Base64Encode) =
  let n = self.config_val("size")
  self.str = repeat('a', n.int)

  self.str2 = encode(self.str)
  self.resultVal = 0

method run(self: Base64Encode, iteration_id: int) =
  self.str2 = encode(self.str)
  self.resultVal = self.resultVal + uint32(self.str2.len)

method checksum(self: Base64Encode): uint32 =
  var ss = "encode "
  if self.str.len > 4:
    ss.add(self.str[0..3] & "...")
  else:
    ss.add(self.str)

  ss.add(" to ")

  if self.str2.len > 4:
    ss.add(self.str2[0..3] & "...")
  else:
    ss.add(self.str2)

  ss.add(": " & $self.resultVal)
  checksum(ss)

registerBenchmark("Base64Encode", newBase64Encode)