package benchmarks

import scala.collection.mutable
import java.util.regex.Pattern

class LogParser extends Benchmark:
  private var linesCount: Int = 0
  private var log: String = ""
  private var checksumVal: Long = 0L

  private val PATTERNS = Array(
    ("errors", Pattern.compile(" [5][0-9]{2} | [4][0-9]{2} ")),
    ("bots", Pattern.compile("bot|crawler|scanner|spider|indexing|crawl|robot|spider", Pattern.CASE_INSENSITIVE)),
    ("suspicious", Pattern.compile("etc/passwd|wp-admin|\\.\\./", Pattern.CASE_INSENSITIVE)),
    ("ips", Pattern.compile("\\d+\\.\\d+\\.\\d+\\.35")),
    ("api_calls", Pattern.compile("/api/[^ \" ]+")),
    ("post_requests", Pattern.compile("POST [^ ]* HTTP")),
    ("auth_attempts", Pattern.compile("/login|/signin", Pattern.CASE_INSENSITIVE)),
    ("methods", Pattern.compile("get|post|put", Pattern.CASE_INSENSITIVE)),
    ("emails", Pattern.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")),
    ("passwords", Pattern.compile("password=[^&\\s\"]+")),
    ("tokens", Pattern.compile("token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+")),
    ("sessions", Pattern.compile("session[_-]?id=[^&\\s\"]+")),
    ("peak_hours", Pattern.compile("\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]"))
  )

  private val IPS = (1 to 255).map(i => s"192.168.1.$i").toArray
  private val METHODS = Array("GET", "POST", "PUT", "DELETE")
  private val PATHS = Array(
    "/index.html",
    "/api/users",
    "/admin",
    "/images/logo.png",
    "/etc/passwd",
    "/wp-admin/setup.php"
  )
  private val STATUSES = Array(200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503)
  private val AGENTS = Array("Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0")
  private val USERS = Array("john", "jane", "alex", "sarah", "mike", "anna", "david", "elena")
  private val DOMAINS = Array("example.com", "gmail.com", "yahoo.com", "hotmail.com", "company.org", "mail.ru")

  override def name(): String = "Etc::LogParser"

  private def generateLogLine(i: Int): String =
    val sb = new StringBuilder()

    sb.append(IPS(i % IPS.length))
    sb.append(f" - - [${i % 31}/Oct/2023:${i % 60}:55:36 +0000] \"")
    sb.append(METHODS(i % METHODS.length))
    sb.append(" ")

    if i % 3 == 0 then sb.append(f"/login?email=${USERS(i % USERS.length)}${i % 100}@${DOMAINS(i % DOMAINS.length)}&password=secret${i % 10000}")
    else if i % 5 == 0 then
      sb.append("/api/data?token=")
      for (_ <- 0 to (i % 3)) do sb.append("abcdef123456")
    else if i % 7 == 0 then sb.append(f"/user/profile?session_id=sess_${i * 12345}%x")
    else sb.append(PATHS(i % PATHS.length))

    sb.append(f" HTTP/1.1\" ${STATUSES(i % STATUSES.length)} 2326 \"http://${DOMAINS(i % DOMAINS.length)}\" \"${AGENTS(i % AGENTS.length)}\"\n")

    sb.toString

  override def prepare(): Unit =
    linesCount = configVal("lines_count").toInt

    val sb = new StringBuilder(linesCount * 200)
    var i = 0
    while i < linesCount do
      sb.append(generateLogLine(i))
      i += 1

    log = sb.toString

  override def run(iterationId: Int): Unit =
    val matches = mutable.Map.empty[String, Int]

    var i = 0
    while i < PATTERNS.length do
      val (name, pattern) = PATTERNS(i)
      val matcher = pattern.matcher(log)
      var count = 0
      while matcher.find() do count += 1
      matches(name) = count
      i += 1

    val total = matches.values.sum
    checksumVal += total

  override def checksum(): Long = checksumVal
