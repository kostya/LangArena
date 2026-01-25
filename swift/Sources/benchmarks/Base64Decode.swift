import Foundation

final class Base64Decode: BenchmarkProtocol {
    private static let TRIES = 8192
    
    private var n: Int = 0
    private var str2: String = ""
    private var str3: String = ""
    private var cachedBase64String: String! // Кэшируем строку в Base64
    private var cachedBase64Data: Data!     // Кэшируем Data из Base64 строки
    private var _result: UInt32 = 0
    
    init() {
        n = iterations
    }
    
    func prepare() {
        // Оптимизированное создание строки
        let bytes = [UInt8](repeating: 97, count: n) // "a" = ASCII 97
        let data = Data(bytes)
        
        // Кодируем в Base64
        str2 = data.base64EncodedString()
        cachedBase64String = str2
        cachedBase64Data = Data(str2.utf8)
        
        // Декодируем для проверки
        if let decoded = Data(base64Encoded: str2) {
            str3 = String(data: decoded, encoding: .utf8) ?? ""
        } else {
            str3 = ""
        }
    }
    
    func run() {
        var sDecoded: Int64 = 0
        
        // РЕАЛЬНОЕ декодирование каждый раз
        for _ in 0..<Base64Decode.TRIES {
            // Используем кэшированную Base64 строку, но декодируем каждый раз
            if let data = Data(base64Encoded: cachedBase64String) {
                sDecoded &+= Int64(data.count)
            }
        }
        
        let message = "decode \(str2.prefix(4))... to \(str3.prefix(4))...: \(sDecoded)\n"
        _result = Helper.checksum(message)
    }
    
    var result: Int64 {
        return Int64(_result)
    }
    
    var iterations: Int {
        let input = Helper.getInput("Base64Decode")
        return Int(input ?? "") ?? 100
    }
}