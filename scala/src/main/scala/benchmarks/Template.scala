package benchmarks

import scala.collection.mutable
import java.util.regex.Pattern

private val FIRST_NAMES = Array("John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike")
private val LAST_NAMES = Array("Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones")
private val CITIES = Array("New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco")
private val LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

abstract class TemplateBase extends Benchmark {
  protected var count: Int = 0
  protected var text: String = ""
  protected var rendered: String = ""
  protected var checksumVal: Long = 0L
  protected val vars = mutable.Map.empty[String, String]

  protected def prepareTemplate(): Unit = {
    vars.clear()
    val sb = new StringBuilder(count * 200)

    sb.append("<html><body>")
    sb.append("<h1>{{TITLE}}</h1>")
    vars("TITLE") = "Template title"
    sb.append("<p>")
    sb.append(LOREM)
    sb.append("</p>")
    sb.append("<table>")

    var i = 0
    while (i < count) {
      if (i % 3 == 0) sb.append("<!-- {comment} -->")
      sb.append("<tr>")
      sb.append(s"<td>{{ FIRST_NAME$i }}</td>")
      sb.append(s"<td>{{LAST_NAME$i}}</td>")
      sb.append(s"<td>{{  CITY$i  }}</td>")

      vars(s"FIRST_NAME$i") = FIRST_NAMES(i % FIRST_NAMES.length)
      vars(s"LAST_NAME$i") = LAST_NAMES(i % LAST_NAMES.length)
      vars(s"CITY$i") = CITIES(i % CITIES.length)

      sb.append(s"<td>{balance: ${i % 100}}</td>")
      sb.append("</tr>\n")
      i += 1
    }

    sb.append("</table>")
    sb.append("</body></html>")

    text = sb.toString
  }

  override def prepare(): Unit = {
    count = configVal("count").toInt
    prepareTemplate()
  }

  override def checksum(): Long = checksumVal + Helper.checksum(rendered)
}

class TemplateRegex extends TemplateBase {
  private val pattern = Pattern.compile("\\{\\{\\s*(.*?)\\s*\\}\\}")

  override def name(): String = "Template::Regex"

  override def run(iterationId: Int): Unit = {
    val sb = new StringBuilder(text.length)
    var lastPos = 0
    val matcher = pattern.matcher(text)

    while (matcher.find()) {
      if (matcher.start() > lastPos) {
        sb.append(text.substring(lastPos, matcher.start()))
      }

      val key = matcher.group(1).trim
      vars.get(key).foreach(sb.append)

      lastPos = matcher.end()
    }

    if (lastPos < text.length) {
      sb.append(text.substring(lastPos))
    }

    rendered = sb.toString
    checksumVal += rendered.length
  }
}

class TemplateParse extends TemplateBase {
  override def name(): String = "Template::Parse"

  override def run(iterationId: Int): Unit = {
    val len = text.length
    val sb = new StringBuilder((len * 1.5).toInt)

    var i = 0
    while (i < len) {
      if (i + 1 < len && text.charAt(i) == '{' && text.charAt(i + 1) == '{') {
        var j = i + 2
        while (j + 1 < len && !(text.charAt(j) == '}' && text.charAt(j + 1) == '}')) {
          j += 1
        }

        if (j + 1 < len) {
          val key = text.substring(i + 2, j).trim
          vars.get(key).foreach(sb.append)
          i = j + 2
        } else {
          sb.append(text.charAt(i))
          i += 1
        }
      } else {
        sb.append(text.charAt(i))
        i += 1
      }
    }

    rendered = sb.toString
    checksumVal += rendered.length
  }
}
