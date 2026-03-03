import std/[strutils, strformat, sequtils, algorithm, math, tables, re]
import ../benchmark
import ../helper

type
  TemplateBase = ref object of Benchmark
    count: int
    checksumVal: uint32
    text: string
    rendered: string
    vars: Table[string, string]

  TemplateRegex* = ref object of TemplateBase
  TemplateParse* = ref object of TemplateBase

const
  FIRST_NAMES = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Sarah", "Mike"]
  LAST_NAMES = ["Smith", "Johnson", "Brown", "Taylor", "Wilson", "Davis",
      "Miller", "Jones"]
  CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "San Francisco"]
  LOREM = "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "

proc newTemplateBase(): TemplateBase =
  TemplateBase()

method prepare(self: TemplateBase) =
  self.count = self.config_val("count").int
  self.checksumVal = 0
  self.vars.clear()

  var sb = newStringOfCap(self.count * 200)
  sb.add("<html><body>")
  sb.add("<h1>{{TITLE}}</h1>")
  self.vars["TITLE"] = "Template title"
  sb.add("<p>")
  sb.add(LOREM)
  sb.add("</p>")
  sb.add("<table>")

  for i in 0..<self.count:
    if i mod 3 == 0:
      sb.add("<!-- {comment} -->")
    sb.add("<tr>")
    sb.add(&"<td>{{{{ FIRST_NAME{i} }}}}</td>")
    sb.add(&"<td>{{{{LAST_NAME{i}}}}}</td>")
    sb.add(&"<td>{{{{  CITY{i}  }}}}</td>")

    self.vars[&"FIRST_NAME{i}"] = FIRST_NAMES[i mod FIRST_NAMES.len]
    self.vars[&"LAST_NAME{i}"] = LAST_NAMES[i mod LAST_NAMES.len]
    self.vars[&"CITY{i}"] = CITIES[i mod CITIES.len]

    sb.add(&"<td>{{balance: {i mod 100}}}</td>")
    sb.add("</tr>\n")

  sb.add("</table>")
  sb.add("</body></html>")
  self.text = sb

method checksum(self: TemplateBase): uint32 =
  self.checksumVal + checksum(self.rendered)

proc newTemplateRegex(): Benchmark =
  TemplateRegex()

method name(self: TemplateRegex): string = "Template::Regex"

method prepare(self: TemplateRegex) =
  procCall self.TemplateBase.prepare()

method run(self: TemplateRegex, iteration_id: int) =
  let pattern = re(r"\{\{\s*(.*?)\s*\}\}")

  var result = newStringOfCap(self.text.len)
  var lastPos = 0
  var pos = 0

  while pos < self.text.len:
    let (startPos, endPos) = self.text.findBounds(pattern, pos)
    if startPos < 0:
      break

    if startPos > lastPos:
      result.add(self.text[lastPos ..< startPos])

    let key = self.text[startPos+2 .. endPos-2].strip()
    if self.vars.hasKey(key):
      result.add(self.vars[key])

    lastPos = endPos + 1
    pos = endPos + 1

  if lastPos < self.text.len:
    result.add(self.text[lastPos .. ^1])

  self.rendered = result
  self.checksumVal += uint32(self.rendered.len)

method checksum(self: TemplateRegex): uint32 =
  procCall self.TemplateBase.checksum()

proc newTemplateParse(): Benchmark =
  TemplateParse()

method name(self: TemplateParse): string = "Template::Parse"

method prepare(self: TemplateParse) =
  procCall self.TemplateBase.prepare()

method run(self: TemplateParse, iteration_id: int) =
  let len = self.text.len
  var result = newStringOfCap(int(float(len) * 1.5))

  var i = 0
  while i < len:
    if i + 1 < len and self.text[i] == '{' and self.text[i+1] == '{':
      var j = i + 2
      while j + 1 < len:
        if self.text[j] == '}' and self.text[j+1] == '}':
          break
        j += 1

      if j + 1 < len:
        let key = self.text[i+2 .. j-1].strip()
        if self.vars.hasKey(key):
          result.add(self.vars[key])
        i = j + 2
        continue

    result.add(self.text[i])
    i += 1

  self.rendered = result
  self.checksumVal += uint32(self.rendered.len)

method checksum(self: TemplateParse): uint32 =
  procCall self.TemplateBase.checksum()

registerBenchmark("Template::Regex", newTemplateRegex)
registerBenchmark("Template::Parse", newTemplateParse)
