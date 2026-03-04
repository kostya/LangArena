import Foundation

struct Helper {
  private static let IM: Int = 139968
  private static let IA: Int = 3877
  private static let IC: Int = 29573
  private static let INIT: Int = 42

  private static var last = INIT
  private static var _order: [String] = []

  static var order: [String] {
    return _order
  }

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

    if !fileManager.fileExists(atPath: filePath) {
      let parentFile = "../test.js"
      if fileManager.fileExists(atPath: parentFile) {
        filePath = parentFile
      } else {
        print("No config file found: test.js")
        config = [:]
        return
      }
    }

    do {
      let contents = try Data(contentsOf: URL(fileURLWithPath: filePath))

      if let jsonArray = try? JSONSerialization.jsonObject(with: contents, options: [])
        as? [[String: Any]]
      {
        var configDict: [String: Any] = [:]
        var orderList: [String] = []

        for item in jsonArray {
          if let name = item["name"] as? String {
            configDict[name] = item
            orderList.append(name)
          }
        }

        config = configDict
        _order = orderList
      } else {
        config = [:]
        _order = []
      }
    } catch {
      print("Error loading config file '\(filePath)': \(error)")
      config = [:]
      _order = []
    }
  }
}
