import std/[strutils, strformat, sequtils, algorithm, math, tables, re]
import ../benchmark
import ../helper

type
  LogParser* = ref object of Benchmark
    linesCount: int
    log: string
    checksumVal: uint32
    patterns: seq[tuple[name: string, pattern: Regex]]

const
  IPS = block:
    var ips: seq[string]
    for i in 1..255:
      ips.add("192.168.1." & $i)
    ips

  METHODS = ["GET", "POST", "PUT", "DELETE"]
  PATHS = [
    "/index.html", "/api/users", "/admin",
    "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php"
  ]
  STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
  AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]
  USERS = ["john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"]
  DOMAINS = ["example.com", "gmail.com", "yahoo.com", "hotmail.com",
      "company.org", "mail.ru"]

  PATTERN_NAMES = [
    "errors", "bots", "suspicious", "ips", "api_calls", "post_requests",
    "auth_attempts", "methods", "emails", "passwords", "tokens", "sessions", "peak_hours"
  ]

  PATTERN_STRS = [
    " [5][0-9]{2} | [4][0-9]{2} ",
    "(?i)bot|crawler|scanner|spider|indexing|crawl|robot|spider",
    "(?i)etc/passwd|wp-admin|\\.\\./",
    "\\d+\\.\\d+\\.\\d+\\.35",
    "/api/[^ \" ]+",
    "POST [^ ]* HTTP",
    "(?i)/login|/signin",
    "(?i)get|post|put",
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    "password=[^&\\s\"]+",
    "token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+",
    "session[_-]?id=[^&\\s\"]+",
    "\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]",
  ]

proc generateLogLine(i: int): string =
  result = newStringOfCap(200)
  result.add IPS[i mod IPS.len]
  result.add &" - - [{i mod 31}/Oct/2023:{i mod 60}:55:36 +0000] \""
  result.add METHODS[i mod METHODS.len]
  result.add " "

  if i mod 3 == 0:
    result.add &"/login?email={USERS[i mod USERS.len]}{i mod 100}@{DOMAINS[i mod DOMAINS.len]}&password=secret{i mod 10000}"
  elif i mod 5 == 0:
    result.add "/api/data?token="
    for _ in 0..(i mod 3):
      result.add "abcdef123456"
  elif i mod 7 == 0:
    result.add &"/user/profile?session_id=sess_{toHex(i * 12345)}"
  else:
    result.add PATHS[i mod PATHS.len]

  result.add &" HTTP/1.1\" {STATUSES[i mod STATUSES.len]} 2326 \"http://{DOMAINS[i mod DOMAINS.len]}\" \"{AGENTS[i mod AGENTS.len]}\"\n"

proc newLogParser(): Benchmark =
  LogParser()

method name(self: LogParser): string = "Etc::LogParser"

method prepare(self: LogParser) =
  self.linesCount = self.config_val("lines_count").int

  var sb = newStringOfCap(self.linesCount * 200)
  for i in 0..<self.linesCount:
    sb.add(generateLogLine(i))

  self.log = sb

  self.patterns = newSeq[tuple[name: string, pattern: Regex]](PATTERN_NAMES.len)
  for i in 0..<PATTERN_NAMES.len:
    self.patterns[i] = (PATTERN_NAMES[i], re(PATTERN_STRS[i]))

  self.checksumVal = 0

method run(self: LogParser, iteration_id: int) =
  var matches = initTable[string, int]()

  for (name, pattern) in self.patterns:
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
