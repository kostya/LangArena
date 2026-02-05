import std/[strutils, json]
import config

type
  Helper* = object
    last*: int64

const
  IM = 139968'i64
  IA = 3877'i64
  IC = 29573'i64

var threadHelper {.threadvar.}: Helper

proc reset*() =
  threadHelper.last = 42

proc nextInt*(max: int32): int32 =
  threadHelper.last = (threadHelper.last * IA + IC) mod IM
  result = int32((threadHelper.last * max) div IM)

proc nextInt*(fromVal, toVal: int32): int32 =
  result = nextInt(toVal - fromVal + 1) + fromVal

proc nextFloat*(max: float = 1.0): float =
  threadHelper.last = (threadHelper.last * IA + IC) mod IM
  result = max * float(threadHelper.last) / float(IM)

proc checksum*(v: string): uint32 =
  result = 5381'u32
  for c in v:
    result = ((result shl 5) + result) + uint32(c.uint8)

proc checksum*(v: openArray[byte]): uint32 =
  result = 5381'u32
  for b in v:
    result = ((result shl 5) + result) + uint32(b)

proc checksumF64*(v: float): uint32 =
  result = checksum(formatFloat(v, ffDecimal, 7))

proc config_i64*(class_name, field_name: string): int64 =
  try:
    if CONFIG.hasKey(class_name) and CONFIG{class_name}.hasKey(field_name):
      return CONFIG{class_name}{field_name}.getInt()
    else:
      raise newException(ValueError, "Config not found for " & class_name & ", field: " & field_name)
  except:
    stderr.writeLine(getCurrentExceptionMsg())
    return 0

proc config_s*(class_name, field_name: string): string =
  try:
    if CONFIG.hasKey(class_name) and CONFIG{class_name}.hasKey(field_name):
      return CONFIG{class_name}{field_name}.getStr()
    else:
      raise newException(ValueError, "Config not found for " & class_name & ", field: " & field_name)
  except:
    stderr.writeLine(getCurrentExceptionMsg())
    return ""