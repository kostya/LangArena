package benchmarks

import Benchmark
import kotlin.text.Regex

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
                "/login",
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

        private val PATTERNS =
            arrayOf(
                "errors" to Regex(" [5][0-9]{2} "),
                "bots" to Regex("bot|crawler|scanner", RegexOption.IGNORE_CASE),
                "suspicious" to Regex("etc/passwd|wp-admin|\\.\\./", RegexOption.IGNORE_CASE),
                "ips" to Regex("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.35"),
                "api_calls" to Regex("/api/[^ \"]+"),
                "post_requests" to Regex("POST [^ ]* HTTP"),
                "auth_attempts" to Regex("/login|/signin", RegexOption.IGNORE_CASE),
                "methods" to Regex("get|post", RegexOption.IGNORE_CASE),
            )
    }

    private fun generateLogLine(i: Int): String =
        "${IPS[i % IPS.size]} - - [${i % 31}/Oct/2023:13:55:36 +0000] \"${METHODS[i % METHODS.size]} ${PATHS[i % PATHS.size]} HTTP/1.0\" ${STATUSES[i % STATUSES.size]} 2326 \"-\" \"${AGENTS[i % AGENTS.size]}\"\n"

    override fun prepare() {
        linesCount = configVal("lines_count").toInt()

        val sb = StringBuilder(linesCount * 150)
        for (i in 0 until linesCount) {
            sb.append(generateLogLine(i))
        }

        log = sb.toString()
    }

    override fun run(iterationId: Int) {
        val matches = mutableMapOf<String, Int>()

        for ((name, regex) in PATTERNS) {
            matches[name] = regex.findAll(log).count()
        }

        val total = matches.values.sum()
        checksumVal += total.toUInt()
    }

    override fun checksum(): UInt = checksumVal

    override fun name(): String = "Etc::LogParser"
}
