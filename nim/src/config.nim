import std/[json, os, streams]

var CONFIG*: JsonNode
var ORDER*: seq[string]

proc loadConfig*(filename = "../test.js") =
  CONFIG = newJObject()
  ORDER = @[]

  if not fileExists(filename):
    stderr.writeLine("Cannot open config file: ", filename)
    return

  try:
    let file = newFileStream(filename, fmRead)
    let jsonArray = parseJson(file)
    file.close()

    var dict = newJObject()
    for item in jsonArray:
      let name = item["name"].getStr()
      dict[name] = item
      ORDER.add(name)

    CONFIG = dict
  except JsonParsingError:
    stderr.writeLine("Error parsing JSON config")
    CONFIG = newJObject()
