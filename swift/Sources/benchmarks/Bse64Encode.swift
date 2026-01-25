import Foundation

final class Base64Encode: BenchmarkProtocol {
    private static let TRIES = 8192
    
    private var n: Int = 0
    private var str: String = ""
    private var str2: String = ""
    private var cachedData: Data!  // Кэшируем Data
    private var _result: UInt32 = 0
    
    init() {
        n = iterations
    }
    
    func prepare() {
        // Быстрое создание строки
        str = String(repeating: "a", count: n)
        // Кэшируем Data один раз
        cachedData = str.data(using: .utf8)!
        str2 = cachedData.base64EncodedString()
    }
    
    func run() {
        var sEncoded: Int64 = 0
        
        // БЫСТРАЯ версия - используем кэшированный Data
        for _ in 0..<Base64Encode.TRIES {
            // Используем кэшированные данные, не создаем новых объектов
            let encoded = cachedData.base64EncodedString()
            sEncoded += Int64(encoded.utf8.count)  // Быстрее чем .count
        }
        
        let message = "encode \(str.prefix(4))... to \(str2.prefix(4))...: \(sEncoded)\n"
        _result = Helper.checksum(message)
    }
    
    var result: Int64 {
        return Int64(_result)
    }
}