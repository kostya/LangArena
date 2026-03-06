import std/[strformat, streams, parsecsv, strutils]
import ../benchmark
import ../helper

type
  CsvParse* = ref object of Benchmark
    rows: int
    data: string
    resultVal: uint32

proc newCsvParse(): Benchmark =
  CsvParse()

method name(self: CsvParse): string = "CSV::Parse"

method prepare(self: CsvParse) =
  self.rows = int(self.config_val("rows"))
  var lines: seq[string] = @[]
  lines.setLen(self.rows)

  for i in 0..<self.rows:
    let c = char(ord('A') + (i mod 26))
    let x = nextFloat(1.0)
    let z = nextFloat(1.0)
    let y = nextFloat(1.0)
    var line = "\"point " & $c & "\\n, \"\"" & $(i mod 100) & "\"\"\"" & ","
    line.add fmt"{x:.10f}" & ","
    line.add ","
    line.add fmt"{z:.10f}" & ","
    let flag = if i mod 2 == 0: "true" else: "false"
    line.add "\"[" & flag & "\\n, " & $(i mod 100) & "]\","
    line.add fmt"{y:.10f}"
    lines[i] = line

  self.data = lines.join("\n")
  self.resultVal = 0

type Point = tuple[x, y, z: float]

method run(self: CsvParse, iteration_id: int) =
  var points: seq[Point] = @[]
  var stream = newStringStream(self.data)
  var parser: CsvParser

  parser.open(stream, "csv_data_" & $iteration_id, separator = ',', quote = '"')

  while parser.readRow():
    let x = parseFloat(parser.row[1])
    let z = parseFloat(parser.row[3])
    let y = parseFloat(parser.row[5])
    points.add((x, y, z))

  parser.close()
  stream.close()

  if points.len == 0:
    return

  var xSum, ySum, zSum: float
  for (x, y, z) in points:
    xSum += x
    ySum += y
    zSum += z

  let cnt = float(points.len)
  let xAvg = xSum / cnt
  let yAvg = ySum / cnt
  let zAvg = zSum / cnt

  self.resultVal = self.resultVal + checksumF64(xAvg) + checksumF64(yAvg) +
      checksumF64(zAvg)

method checksum(self: CsvParse): uint32 =
  self.resultVal

registerBenchmark("CSV::Parse", newCsvParse)
{.used.}
