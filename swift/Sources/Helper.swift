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
        // debug { "checksum: \(v.inspect())" }
        var hash: UInt32 = 5381
        for char in v.unicodeScalars {
            hash = ((hash &<< 5) &+ hash) &+ UInt32(char.value)
        }
        return hash
    }
    
    static func checksum(_ v: [UInt8]) -> UInt32 {
        // debug { "checksum: \(v)" }
        var hash: UInt32 = 5381
        for byte in v {
            hash = ((hash &<< 5) &+ hash) &+ UInt32(byte)
        }
        return hash
    }
    
    static func checksumF64(_ v: Double) -> UInt32 {
        return checksum(String(format: "%.7f", v))
    }
    
    // Конфигурация - ТОЧНО как в Kotlin: все значения как String
    static var input: [String: String] = [:]
    static var expect: [String: Int64] = [:]
    
    static func loadConfig(filename: String? = nil) throws {
        let file = filename ?? "test.txt"
        
        // Определяем путь к файлу
        let fileManager = FileManager.default
        var filePath = file
        
        // Сначала проверяем текущую директорию
        if fileManager.fileExists(atPath: filePath) {
            //print("Loading config from: \(filePath)")
        } else {
            // Пробуем родительскую директорию
            let parentFile = "../test.txt"
            if fileManager.fileExists(atPath: parentFile) {
                filePath = parentFile
                // print("Loading config from: \(parentFile)")
            } else {
                // Создаем тестовый файл если нет
                print("No config file: ../test.txt")
                filePath = "test.txt"
            }
        }
        
        let contents = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = contents.split(separator: "\n").map { String($0) }
        
        var loaded = 0
        for line in lines where !line.isEmpty {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            if parts.count == 3 {
                let name = String(parts[0])
                let value = String(parts[1])
                let expected = Int64(parts[2]) ?? 0
                
                input[name] = value
                expect[name] = expected
                loaded += 1
            }
        }
        
        // print("Loaded \(loaded) benchmarks from config")
    }
        
    // Метод для получения значения как в Kotlin
    static func getInput(_ className: String) -> String {
        return input[className] ?? ""
    }
    
    static func getExpect(_ className: String) -> Int64 {
        return expect[className] ?? 0
    }
}

// Extension для inspect (аналог Kotlin)
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