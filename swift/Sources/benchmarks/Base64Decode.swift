import Foundation

final class Base64Decode: BenchmarkProtocol {
  private var sizeVal: Int64 = 0
  private var str2: String = ""
  private var bytes: [UInt8] = []
  private var resultVal: UInt32 = 0

  init() {
    sizeVal = configValue("size") ?? 0
  }

  func prepare() {
    let str = String(repeating: "a", count: Int(sizeVal))
    let data = str.data(using: .utf8)!

    str2 = data.base64EncodedString()
  }

  func run(iterationId: Int) {
    if let data = Data(base64Encoded: str2) {
      bytes = [UInt8](data)
      resultVal &+= UInt32(data.count)
    }
  }

  var checksum: UInt32 {
    let str3 = String(bytes: bytes.prefix(5), encoding: .utf8) ?? "-"
    let truncatedStr2 = str2.count > 4 ? String(str2.prefix(4)) + "..." : str2
    let truncatedStr3 = str3.count > 4 ? String(str3.prefix(4)) + "..." : str3
    let message = "decode \(truncatedStr2) to \(truncatedStr3): \(resultVal)"
    return Helper.checksum(message)
  }

  func name() -> String {
    return "Base64::Decode"
  }
}
