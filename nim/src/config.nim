import std/[json, os, streams]

var CONFIG*: JsonNode

proc loadConfig*(filename = "../test.js") =

  CONFIG = newJObject()

  if not fileExists(filename):
    stderr.writeLine("Cannot open config file: ", filename)
    return

  try:
    let file = newFileStream(filename, fmRead)
    CONFIG = parseJson(file)
    file.close()
  except JsonParsingError:
    stderr.writeLine("Error parsing JSON config")
    CONFIG = newJObject()