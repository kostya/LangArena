package benchmarks

import Benchmark
import java.util.regex.Pattern

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
    private val pattern = Pattern.compile("\\{\\{(.*?)\\}\\}")

    override fun name(): String = "Template::Regex"

    override fun run(iterationId: Int) {
        val sb = StringBuilder(text.length)
        val matcher = pattern.matcher(text)
        var lastEnd = 0

        while (matcher.find()) {
            sb.append(text, lastEnd, matcher.start())
            val value = vars[matcher.group(1).trim()]
            if (value != null) {
                sb.append(value)
            }
            lastEnd = matcher.end()
        }
        sb.append(text, lastEnd, text.length)

        rendered = sb.toString()
        checksumVal += rendered.length.toUInt()
    }
}

class TemplateParse : TemplateBase() {
    override fun name(): String = "Template::Parse"

    override fun run(iterationId: Int) {
        val len = text.length
        val sb = StringBuilder((len * 1.5).toInt())

        var i = 0
        while (i < len) {
            if (i + 1 < len && text[i] == '{' && text[i + 1] == '{') {
                var j = i + 2
                while (j + 1 < len && !(text[j] == '}' && text[j + 1] == '}')) {
                    j++
                }

                if (j + 1 < len) {
                    val key = text.substring(i + 2, j).trim()
                    val value = vars[key]
                    if (value != null) {
                        sb.append(value)
                    }
                    i = j + 2
                    continue
                }
            }

            sb.append(text[i])
            i++
        }

        rendered = sb.toString()
        checksumVal += rendered.length.toUInt()
    }
}
