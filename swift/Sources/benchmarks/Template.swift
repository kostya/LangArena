import Foundation

let FIRST_NAMES = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"]
let LAST_NAMES = ["Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis", "Miller", "Jones"]
let CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"]
let LOREM =
  "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

func prepareTemplate(count: Int, vars: inout [String: String], text: inout String) {
  var textBuilder = ""
  textBuilder.reserveCapacity(count * 200)
  vars.removeAll()

  textBuilder.append("<html><body>")
  textBuilder.append("<h1>{{TITLE}}</h1>")
  vars["TITLE"] = "Template title"
  textBuilder.append("<p>")
  textBuilder.append(LOREM)
  textBuilder.append("</p>")
  textBuilder.append("<table>")

  for i in 0..<count {
    if i % 3 == 0 {
      textBuilder.append("<!-- {comment} -->")
    }
    textBuilder.append("<tr>")
    textBuilder.append("<td>{{ FIRST_NAME\(i) }}</td>")
    textBuilder.append("<td>{{LAST_NAME\(i)}}</td>")
    textBuilder.append("<td>{{  CITY\(i)  }}</td>")

    vars["FIRST_NAME\(i)"] = FIRST_NAMES[i % FIRST_NAMES.count]
    vars["LAST_NAME\(i)"] = LAST_NAMES[i % LAST_NAMES.count]
    vars["CITY\(i)"] = CITIES[i % CITIES.count]

    textBuilder.append("<td>{balance: \(i % 100)}</td>")
    textBuilder.append("</tr>\n")
  }

  textBuilder.append("</table>")
  textBuilder.append("</body></html>")

  text = textBuilder
}

final class TemplateRegex: BenchmarkProtocol {
  private var count: Int
  private var checksumVal: UInt32
  private var text: String
  private var rendered: String
  private var vars: [String: String]
  private let regex: NSRegularExpression

  init() {

    self.count = 0
    self.checksumVal = 0
    self.text = ""
    self.rendered = ""
    self.vars = [:]
    self.regex = try! NSRegularExpression(pattern: "\\{\\{(.*?)\\}\\}")

    self.count = Int(configValue("count") ?? 0)
  }

  func prepare() {
    prepareTemplate(count: count, vars: &vars, text: &text)
  }

  func run(iterationId: Int) {
    var result = ""
    result.reserveCapacity(text.count)

    let nsRange = NSRange(text.startIndex..., in: text)
    var lastPos = text.startIndex

    let matches = regex.matches(in: text, range: nsRange)
    for match in matches {
      let matchRange = Range(match.range, in: text)!

      result.append(contentsOf: text[lastPos..<matchRange.lowerBound])

      if let keyRange = Range(match.range(at: 1), in: text) {
        let key = String(text[keyRange]).trimmingCharacters(in: .whitespaces)
        if let value = vars[key] {
          result.append(value)
        }
      }

      lastPos = matchRange.upperBound
    }

    if lastPos < text.endIndex {
      result.append(contentsOf: text[lastPos...])
    }

    rendered = result
    checksumVal &+= UInt32(rendered.utf8.count)
  }

  var checksum: UInt32 {
    return checksumVal &+ Helper.checksum(rendered)
  }

  func name() -> String {
    return "Template::Regex"
  }
}

final class TemplateParse: BenchmarkProtocol {
  private var count: Int
  private var checksumVal: UInt32
  private var text: String
  private var rendered: String
  private var vars: [String: String]

  init() {

    self.count = 0
    self.checksumVal = 0
    self.text = ""
    self.rendered = ""
    self.vars = [:]

    self.count = Int(configValue("count") ?? 0)
  }

  func prepare() {
    prepareTemplate(count: count, vars: &vars, text: &text)
  }

  func run(iterationId: Int) {
    let chars = Array(text)
    let len = chars.count
    var result = ""
    result.reserveCapacity(Int(Double(len) * 1.5))

    var i = 0
    while i < len {
      if i + 1 < len && chars[i] == "{" && chars[i + 1] == "{" {
        var j = i + 2
        while j + 1 < len && !(chars[j] == "}" && chars[j + 1] == "}") {
          j += 1
        }

        if j + 1 < len {
          let key = String(chars[(i + 2)..<j]).trimmingCharacters(in: .whitespaces)
          if let value = vars[key] {
            result.append(value)
          }
          i = j + 2
          continue
        }
      }

      result.append(chars[i])
      i += 1
    }

    rendered = result
    checksumVal &+= UInt32(rendered.utf8.count)
  }

  var checksum: UInt32 {
    return checksumVal &+ Helper.checksum(rendered)
  }

  func name() -> String {
    return "Template::Parse"
  }
}
