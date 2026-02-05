import Foundation

final class Base64Decode: BenchmarkProtocol {
    private var sizeVal: Int64 = 0
    private var str2: String = ""
    private var str3: String = ""
    private var resultVal: UInt32 = 0

    init() {
        sizeVal = configValue("size") ?? 0
    }

    func prepare() {
        let str = String(repeating: "a", count: Int(sizeVal))
        let data = str.data(using: .utf8)!

        str2 = data.base64EncodedString()

        if let decoded = Data(base64Encoded: str2) {
            str3 = String(data: decoded, encoding: .utf8) ?? ""
        } else {
            str3 = ""
        }
    }

    private func base64DecodeSimple(_ input: String) -> String {
        if let data = Data(base64Encoded: input) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return ""
    }

    func run(iterationId: Int) {
        str3 = base64DecodeSimple(str2)
        resultVal &+= UInt32(str3.count) 
    }

    var checksum: UInt32 {
        let truncatedStr2 = str2.count > 4 ? String(str2.prefix(4)) + "..." : str2
        let truncatedStr3 = str3.count > 4 ? String(str3.prefix(4)) + "..." : str3
        let message = "decode \(truncatedStr2) to \(truncatedStr3): \(resultVal)"
        return Helper.checksum(message)
    }
}