import Foundation

final class Base64Encode: BenchmarkProtocol {
    private var sizeVal: Int64 = 0
    private var str: String = ""
    private var str2: String = ""
    private var resultVal: UInt32 = 0

    init() {
        sizeVal = configValue("size") ?? 0
    }

    private func base64EncodeSimple(_ input: String) -> String {
        let data = input.data(using: .utf8)!
        return data.base64EncodedString()
    }

    func prepare() {
        str = String(repeating: "a", count: Int(sizeVal))
        let data = str.data(using: .utf8)!
        str2 = data.base64EncodedString()
    }

    func run(iterationId: Int) {
        str2 = base64EncodeSimple(str)
        resultVal &+= UInt32(str2.count)
    }

    var checksum: UInt32 {
        let truncatedStr = str.count > 4 ? String(str.prefix(4)) + "..." : str
        let truncatedStr2 = str2.count > 4 ? String(str2.prefix(4)) + "..." : str2
        let message = "encode \(truncatedStr) to \(truncatedStr2): \(resultVal)"
        return Helper.checksum(message)
    }
}