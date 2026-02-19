import Foundation

struct Helper {
  private static let IM: Int = 139968
  private static let IA: Int = 3877
  private static let IC: Int = 29573
  private static let INIT: Int = 42

  private static var last = INIT

  static func reset() {
    last = INIT
  }

  static func nextInt(max: Int) -> Int {
    last = (last * IA + IC) % IM
    return Int((Double(last) / Double(IM)) * Double(max))
  }

  static func nextInt(from: Int, to: Int) -> Int {
    return nextInt(max: to - from + 1) + from
  }

  static func nextFloat(max: Double = 1.0) -> Double {
    last = (last * IA + IC) % IM
    return max * Double(last) / Double(IM)
  }

  static func debug(_ message: () -> String) {
    if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
      print(message())
    }
  }

  static func checksum(_ v: String) -> UInt32 {
    var hash: UInt32 = 5381
    for char in v.unicodeScalars {
      hash = ((hash &<< 5) &+ hash) &+ UInt32(char.value)
    }
    return hash
  }

  static func checksum(_ v: [UInt8]) -> UInt32 {
    var hash: UInt32 = 5381
    for byte in v {
      hash = ((hash &<< 5) &+ hash) &+ UInt32(byte)
    }
    return hash
  }

  static func checksumF64(_ v: Double) -> UInt32 {
    return checksum(String(format: "%.7f", v))
  }

  static var config: [String: Any] = [:]

  static func loadConfig(filename: String? = nil) throws {
    let file = filename ?? "test.js"

    let fileManager = FileManager.default
    var filePath = file

    if fileManager.fileExists(atPath: filePath) {

    } else {

      let parentFile = "../test.js"
      if fileManager.fileExists(atPath: parentFile) {
        filePath = parentFile
      } else {
        print("No config file found: test.js or test.txt")
        config = [:]
        return
      }
    }

    do {
      let contents = try Data(contentsOf: URL(fileURLWithPath: filePath))

      if let json = try? JSONSerialization.jsonObject(with: contents, options: []) as? [String: Any]
      {
        config = json
      } else {

        let oldContents = try String(contentsOfFile: filePath, encoding: .utf8)
        config = convertOldFormat(oldContents)
      }
    } catch {
      print("Error loading config file '\(filePath)': \(error)")
      config = [:]
    }
  }

  private static func convertOldFormat(_ contents: String) -> [String: Any] {
    var jsonConfig: [String: Any] = [:]
    let lines = contents.split(separator: "\n").map { String($0) }

    for line in lines where !line.isEmpty {
      let parts = line.split(separator: "|", omittingEmptySubsequences: false)
      if parts.count == 3 {
        let name = String(parts[0])
        let value = String(parts[1])
        let checksum = Int64(parts[2]) ?? 0

        if let iterations = Int(value) {
          jsonConfig[name] = [
            "iterations": iterations,
            "checksum": checksum,
          ]
        } else {

          jsonConfig[name] = [
            "input": value,
            "checksum": checksum,
          ]
        }
      }
    }

    return jsonConfig
  }
}

extension String {
  func inspect() -> String {
    return self.map { char in
      switch char {
      case "\n": return "\\n"
      case "\r": return "\\r"
      case "\t": return "\\t"
      case "\\": return "\\\\"
      case "\"": return "\\\""
      default:
        let scalar = char.unicodeScalars.first!
        if scalar.value >= 32 && scalar.value <= 126 {
          return String(char)
        } else {
          return String(format: "\\u%04x", scalar.value)
        }
      }
    }.joined(separator: "")
  }
}
