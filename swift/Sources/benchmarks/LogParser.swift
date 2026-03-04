import Foundation

final class LogParser: BenchmarkProtocol {
  private var linesCount: Int = 0
  private var log: String = ""
  private var checksumVal: UInt32 = 0

  private let PATTERNS: [(String, NSRegularExpression)] = [
    ("errors", try! NSRegularExpression(pattern: " [5][0-9]{2} | [4][0-9]{2} ")),
    (
      "bots",
      try! NSRegularExpression(
        pattern: "bot|crawler|scanner|spider|indexing|crawl|robot|spider", options: .caseInsensitive
      )
    ),
    (
      "suspicious",
      try! NSRegularExpression(pattern: "etc/passwd|wp-admin|\\.\\./", options: .caseInsensitive)
    ),
    ("ips", try! NSRegularExpression(pattern: "\\d+\\.\\d+\\.\\d+\\.35")),
    ("api_calls", try! NSRegularExpression(pattern: "/api/[^ \" ]+")),
    ("post_requests", try! NSRegularExpression(pattern: "POST [^ ]* HTTP")),
    (
      "auth_attempts",
      try! NSRegularExpression(pattern: "/login|/signin", options: .caseInsensitive)
    ),
    ("methods", try! NSRegularExpression(pattern: "get|post|put", options: .caseInsensitive)),
    (
      "emails", try! NSRegularExpression(pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")
    ),
    ("passwords", try! NSRegularExpression(pattern: "password=[^&\\s\"]+")),
    ("tokens", try! NSRegularExpression(pattern: "token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+")),
    ("sessions", try! NSRegularExpression(pattern: "session[_-]?id=[^&\\s\"]+")),
    (
      "peak_hours",
      try! NSRegularExpression(pattern: "\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]")
    ),
  ]

  private let IPS: [String] = (1...255).map { "192.168.1.\($0)" }
  private let METHODS = ["GET", "POST", "PUT", "DELETE"]
  private let PATHS = [
    "/index.html", "/api/users", "/admin",
    "/images/logo.png", "/etc/passwd", "/wp-admin/setup.php",
  ]
  private let STATUSES = [200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503]
  private let AGENTS = ["Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0"]
  private let USERS = ["john", "jane", "alex", "sarah", "mike", "anna", "david", "elena"]
  private let DOMAINS = [
    "example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru",
  ]

  init() {
    linesCount = Int(configValue("lines_count") ?? 0)
  }

  private func generateLogLine(_ i: Int) -> String {
    var result = ""
    result.reserveCapacity(200)

    result += IPS[i % IPS.count]
    result += " - - [\(i % 31)/Oct/2023:\(i % 60):55:36 +0000] \""
    result += METHODS[i % METHODS.count]
    result += " "

    if i % 3 == 0 {
      result +=
        "/login?email=\(USERS[i % USERS.count])\(i % 100)@\(DOMAINS[i % DOMAINS.count])&password=secret\(i % 10000)"
    } else if i % 5 == 0 {
      result += "/api/data?token="
      for _ in 0...(i % 3) {
        result += "abcdef123456"
      }
    } else if i % 7 == 0 {
      result += "/user/profile?session_id=sess_\(String(i * 12345, radix: 16))"
    } else {
      result += PATHS[i % PATHS.count]
    }

    result +=
      " HTTP/1.1\" \(STATUSES[i % STATUSES.count]) 2326 \"http://\(DOMAINS[i % DOMAINS.count])\" \"\(AGENTS[i % AGENTS.count])\"\n"

    return result
  }

  func prepare() {
    var logBuilder = ""
    logBuilder.reserveCapacity(linesCount * 200)

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
