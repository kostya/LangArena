import std/[strutils, strformat, sequtils, algorithm, math, tables, re]
import ../benchmark
import ../helper

type
  LogParser* = ref object of Benchmark
    linesCount: int
    log: string
    checksumVal: uint32

const
  IPS = block:
    var ips: seq[string]
    for i in 1..255:
      ips.add("192.168.1." & $i)
    ips

  METHODS = ["GET", "POST", "PUT", "DELETE"]
  PATHS = [
    "/index.html", "/api/users", "/login", "/admin",
    "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
  ]
  STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
  AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]

  PATTERN_NAMES = ["errors", "bots", "suspicious", "ips",
                   "api_calls", "post_requests", "auth_attempts", "methods"]
  PATTERN_STRS = [
    " [5][0-9]{2} ",
    "bot|crawler|scanner",
    "etc/passwd|wp-admin|\\.\\./",
    "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35",
    "/api/[^ \'\']+",
    "POST [^ ]* HTTP",
    "/login|/signin",
    "get|post",
  ]

proc generateLogLine(i: int): string =
  result = &"{IPS[i mod IPS.len]} - - [{i mod 31}/Oct/2023:13:55:36 +0000] \"{METHODS[i mod METHODS.len]} {PATHS[i mod PATHS.len]} HTTP/1.0\" {STATUSES[i mod STATUSES.len]} 2326 \"-\" \"{AGENTS[i mod AGENTS.len]}\"\n"

proc newLogParser(): Benchmark =
  LogParser()

method name(self: LogParser): string = "Etc::LogParser"

method prepare(self: LogParser) =
  self.linesCount = self.config_val("lines_count").int

  var sb = newStringOfCap(self.linesCount * 150)
  for i in 0..<self.linesCount:
    sb.add(generateLogLine(i))

  self.log = sb
  self.checksumVal = 0

method run(self: LogParser, iteration_id: int) =
  var matches = initTable[string, int]()

  for i in 0..<PATTERN_NAMES.len:
    let name = PATTERN_NAMES[i]
    let patternStr = PATTERN_STRS[i]
    let pattern = re(patternStr, {reIgnoreCase})

    var count = 0
    var pos = 0
    while pos < self.log.len:
      let (first, last) = self.log.findBounds(pattern, pos)
      if first < 0:
        break
      inc count
      pos = last + 1
    matches[name] = count

  var total = 0
  for count in matches.values:
    total += count
  self.checksumVal += total.uint32

method checksum(self: LogParser): uint32 =
  return self.checksumVal

registerBenchmark("Etc::LogParser", newLogParser)
