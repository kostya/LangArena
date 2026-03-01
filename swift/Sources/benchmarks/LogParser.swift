import Foundation

final class LogParser: BenchmarkProtocol {
  private var linesCount: Int = 0
  private var log: String = ""
  private var checksumVal: UInt32 = 0

  private let PATTERNS: [(String, NSRegularExpression)] = [
    ("errors", try! NSRegularExpression(pattern: " [5][0-9]{2} ")),
    ("bots", try! NSRegularExpression(pattern: "bot|crawler|scanner", options: .caseInsensitive)),
    (
      "suspicious",
      try! NSRegularExpression(pattern: "etc/passwd|wp-admin|\\.\\./", options: .caseInsensitive)
    ),
    ("ips", try! NSRegularExpression(pattern: "\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35")),
    ("api_calls", try! NSRegularExpression(pattern: "/api/[^ \"]+")),
    ("post_requests", try! NSRegularExpression(pattern: "POST [^ ]* HTTP")),
    (
      "auth_attempts",
      try! NSRegularExpression(pattern: "/login|/signin", options: .caseInsensitive)
    ),
    ("methods", try! NSRegularExpression(pattern: "get|post", options: .caseInsensitive)),
  ]

  private let IPS: [String] = (1...255).map { "192.168.1.\($0)" }
  private let METHODS = ["GET", "POST", "PUT", "DELETE"]
  private let PATHS = [
    "/index.html", "/api/users", "/login", "/admin",
    "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php",
  ]
  private let STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
  private let AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]

  init() {
    linesCount = Int(configValue("lines_count") ?? 0)
  }

  private func generateLogLine(_ i: Int) -> String {
    return
      "\(IPS[i % IPS.count]) - - [\(i % 31)/Oct/2023:13:55:36 +0000] \"\(METHODS[i % METHODS.count]) \(PATHS[i % PATHS.count]) HTTP/1.0\" \(STATUSES[i % STATUSES.count]) 2326 \"-\" \"\(AGENTS[i % AGENTS.count])\"\n"
  }

  func prepare() {
    var logBuilder = ""
    logBuilder.reserveCapacity(linesCount * 150)

    for i in 0..<linesCount {
      logBuilder.append(generateLogLine(i))
    }

    log = logBuilder
  }

  func run(iterationId: Int) {
    var matches: [String: Int] = [:]

    for (name, regex) in PATTERNS {
      let range = NSRange(log.startIndex..., in: log)
      let count = regex.matches(in: log, range: range).count
      matches[name] = count
    }

    let total = matches.values.reduce(0, +)
    checksumVal &+= UInt32(total)
  }

  var checksum: UInt32 {
    return checksumVal
  }

  func name() -> String {
    return "Etc::LogParser"
  }
}
