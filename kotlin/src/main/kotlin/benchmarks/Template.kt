package benchmarks

import Benchmark
import kotlin.text.Regex

private val FIRST_NAMES = arrayOf("John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike")
private val LAST_NAMES = arrayOf("Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones")
private val CITIES = arrayOf("New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco")
private const val LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

abstract class TemplateBase : Benchmark() {
    protected var count: Int = 0
    protected lateinit var text: String
    protected lateinit var rendered: String
    protected var checksumVal: UInt = 0u
    protected val vars = mutableMapOf<String, String>()

    override fun prepare() {
        count = configVal("count").toInt()
        vars.clear()

        val sb = StringBuilder(count * 200)

        sb.append("<html><body>")
        sb.append("<h1>{{TITLE}}</h1>")
        vars["TITLE"] = "Template title"
        sb.append("<p>")
        sb.append(LOREM)
        sb.append("</p>")
        sb.append("<table>")

        for (i in 0 until count) {
            if (i % 3 == 0) {
                sb.append("<!-- {comment} -->")
            }
            sb.append("<tr>")
            sb.append("<td>{{ FIRST_NAME$i }}</td>")
            sb.append("<td>{{LAST_NAME$i}}</td>")
            sb.append("<td>{{  CITY$i  }}</td>")

            vars["FIRST_NAME$i"] = FIRST_NAMES[i % FIRST_NAMES.size]
            vars["LAST_NAME$i"] = LAST_NAMES[i % LAST_NAMES.size]
            vars["CITY$i"] = CITIES[i % CITIES.size]

            sb.append("<td>{balance: ${i % 100}}</td>")
            sb.append("</tr>\n")
        }

        sb.append("</table>")
        sb.append("</body></html>")

        text = sb.toString()
    }

    override fun checksum(): UInt = checksumVal + Helper.checksum(rendered)
}

class TemplateRegex : TemplateBase() {
    private val regex = Regex("\\{\\{\\s*(.*?)\\s*\\}\\}")

    override fun name(): String = "Template::Regex"

    override fun run(iterationId: Int) {
        val sb = StringBuilder(text.length)
        var lastPos = 0

        for (match in regex.findAll(text)) {
            val start = match.range.first
            if (start > lastPos) {
                sb.append(text, lastPos, start)
            }

            val key = match.groupValues[1].trim()
            val value = vars[key]
            if (value != null) {
                sb.append(value)
            }

            lastPos = match.range.last + 1
        }

        if (lastPos < text.length) {
            sb.append(text, lastPos, text.length)
        }

        rendered = sb.toString()
        checksumVal += rendered.length.toUInt()
    }
}

class TemplateParse : TemplateBase() {
    override fun name(): String = "Template::Parse"

    override fun run(iterationId: Int) {
        val len = text.length
        val sb = StringBuilder((len * 1.5).toInt())

        val chars = text.toCharArray()

        var i = 0
        while (i < len) {
            if (i + 1 < len && chars[i] == '{' && chars[i + 1] == '{') {
                var j = i + 2
                while (j + 1 < len && !(chars[j] == '}' && chars[j + 1] == '}')) {
                    j++
                }

                if (j + 1 < len) {
                    val key = String(chars, i + 2, j - i - 2).trim()
                    val value = vars[key]
                    if (value != null) {
                        sb.append(value)
                    }
                    i = j + 2
                    continue
                }
            }

            sb.append(chars[i])
            i++
        }

        rendered = sb.toString()
        checksumVal += rendered.length.toUInt()
    }
}
