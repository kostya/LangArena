import Foundation

final class Base64Encode: BenchmarkProtocol {
    private var sizeVal: Int64 = 0
    private var bytes: [UInt8] = []
    private var str2: String = ""
    private var resultVal: UInt32 = 0

    init() {
        sizeVal = configValue("size") ?? 0
    }

    func prepare() {
        let chars = [Character](repeating: "a", count: Int(sizeVal))
        let str = String(chars)

        bytes = [UInt8](str.data(using: .utf8)!)
        let data = Data(bytes: bytes, count: bytes.count)
        str2 = data.base64EncodedString()
    }

    func run(iterationId: Int) {
        let data = Data(bytes: bytes, count: bytes.count)
        str2 = data.base64EncodedString(options: [])
        resultVal &+= UInt32(str2.count)
    }

    var checksum: UInt32 {
        let str = String(bytes: bytes.prefix(5), encoding: .utf8) ?? "-"
        let truncatedStr = str.count > 4 ? String(str.prefix(4)) + "..." : str
        let truncatedStr2 = str2.count > 4 ? String(str2.prefix(4)) + "..." : str2
        let message = "encode \(truncatedStr) to \(truncatedStr2): \(resultVal)"
        return Helper.checksum(message)
    }
}