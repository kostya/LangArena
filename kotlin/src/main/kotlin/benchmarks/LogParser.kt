package benchmarks

import Benchmark
import java.util.regex.Pattern

class LogParser : Benchmark() {
    private var linesCount: Int = 0
    private lateinit var log: String
    private var checksumVal: UInt = 0u

    companion object {
        private val IPS = (1..255).map { "192.168.1.$it" }.toTypedArray()
        private val METHODS = arrayOf("GET", "POST", "PUT", "DELETE")
        private val PATHS =
            arrayOf(
                "/index.html",
                "/api/users",
                "/admin",
                "/images/logo.png",
                "/etc/passwd",
                "/wp-admin/setup.php",
            )
        private val STATUSES = arrayOf(200, 201, 301, 302, 400, 401, 403, 404, 500, 502, 503)
        private val AGENTS =
            arrayOf(
                "Mozilla/5.0",
                "Googlebot/2.1",
                "curl/7.68.0",
                "scanner/2.0",
            )
        private val USERS =
            arrayOf(
                "john",
                "jane",
                "alex",
                "sarah",
                "mike",
                "anna",
                "david",
                "elena",
            )
        private val DOMAINS =
            arrayOf(
                "example.com",
                "gmail.com",
                "yahoo.com",
                "hotmail.com",
                "company.org",
                "mail.ru",
            )

        private val PATTERNS =
            arrayOf(
                Pattern.compile(" [5][0-9]{2} | [4][0-9]{2} "),
                Pattern.compile("bot|crawler|scanner|spider|indexing|crawl|robot|spider", Pattern.CASE_INSENSITIVE),
                Pattern.compile("etc/passwd|wp-admin|\\.\\./", Pattern.CASE_INSENSITIVE),
                Pattern.compile("\\d+\\.\\d+\\.\\d+\\.35"),
                Pattern.compile("/api/[^ \" ]+"),
                Pattern.compile("POST [^ ]* HTTP"),
                Pattern.compile("/login|/signin", Pattern.CASE_INSENSITIVE),
                Pattern.compile("get|post|put", Pattern.CASE_INSENSITIVE),
                Pattern.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
                Pattern.compile("password=[^&\\s\"]+"),
                Pattern.compile("token=[^&\\s\"]+|api[_-]?key=[^&\\s\"]+"),
                Pattern.compile("session[_-]?id=[^&\\s\"]+"),
                Pattern.compile("\\[\\d+/\\w+/\\d+:1[3-7]:\\d+:\\d+ [+\\-]\\d+\\]"),
            )
    }

    private fun generateLogLine(i: Int): String {
        val sb = StringBuilder()

        sb.append(IPS[i % IPS.size])
        sb.append(" - - [${i % 31}/Oct/2023:${i % 60}:55:36 +0000] \"")
        sb.append(METHODS[i % METHODS.size])
        sb.append(' ')

        when {
            i % 3 == 0 -> {
                sb.append("/login?email=${USERS[i % USERS.size]}${i % 100}@${DOMAINS[i % DOMAINS.size]}&password=secret${i % 10000}")
            }

            i % 5 == 0 -> {
                sb.append("/api/data?token=")
                repeat((i % 3) + 1) {
                    sb.append("abcdef123456")
                }
            }

            i % 7 == 0 -> {
                sb.append("/user/profile?session_id=sess_${(i * 12345).toString(16)}")
            }

            else -> {
                sb.append(PATHS[i % PATHS.size])
            }
        }

        sb.append(
            " HTTP/1.1\" ${STATUSES[i % STATUSES.size]} 2326 \"http://${DOMAINS[i % DOMAINS.size]}\" \"${AGENTS[i % AGENTS.size]}\"\n",
        )

        return sb.toString()
    }

    override fun prepare() {
        linesCount = configVal("lines_count").toInt()

        val sb = StringBuilder(linesCount * 200)
        for (i in 0 until linesCount) {
            sb.append(generateLogLine(i))
        }

        log = sb.toString()
    }

    override fun run(iterationId: Int) {
        var total = 0
        for (pattern in PATTERNS) {
            val matcher = pattern.matcher(log)
            while (matcher.find()) total++
        }
        checksumVal += total.toUInt()
    }

    override fun checksum(): UInt = checksumVal

    override fun name(): String = "Etc::LogParser"
}
