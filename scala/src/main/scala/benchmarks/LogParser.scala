package benchmarks

import scala.collection.mutable
import java.util.regex.Pattern

class LogParser extends Benchmark:
  private var linesCount: Int = 0
  private var log: String = ""
  private var checksumVal: Long = 0L

  private val PATTERNS = Array(
    ("errors", Pattern.compile(" [5][0-9]{2} ")),
    ("bots", Pattern.compile("bot|crawler|scanner", Pattern.CASE_INSENSITIVE)),
    ("suspicious", Pattern.compile("etc/passwd|wp-admin|\\.\\./", Pattern.CASE_INSENSITIVE)),
    ("ips", Pattern.compile("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35")),
    ("api_calls", Pattern.compile("/api/[^ \"]+")),
    ("post_requests", Pattern.compile("POST [^ ]* HTTP")),
    ("auth_attempts", Pattern.compile("/login|/signin", Pattern.CASE_INSENSITIVE)),
    ("methods", Pattern.compile("get|post", Pattern.CASE_INSENSITIVE))
  )

  private val IPS = (1 to 255).map(i => s"192.168.1.$i").toArray
  private val METHODS = Array("GET", "POST", "PUT", "DELETE")
  private val PATHS = Array(
    "/index.html",
    "/api/users",
    "/login",
    "/admin",
    "/images/logo.png",
    "/etc/passwd",
    "/wp-admin/setup.php"
  )
  private val STATUSES = Array(200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503)
  private val AGENTS = Array("Mozilla/5.0", "Googlebot/2.1", "curl/7.68.0", "scanner/2.0")

  override def name(): String = "Etc::LogParser"

  private def generateLogLine(i: Int): String =
    f"${IPS(i % IPS.length)} - - [${i % 31}/Oct/2023:13:55:36 +0000] \"${METHODS(i % METHODS.length)} ${PATHS(i % PATHS.length)} HTTP/1.0\" ${STATUSES(i % STATUSES.length)} 2326 \"-\" \"${AGENTS(i % AGENTS.length)}\"\n"

  override def prepare(): Unit =
    linesCount = configVal("lines_count").toInt

    val sb = new StringBuilder(linesCount * 150)
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
