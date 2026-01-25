import Foundation

// Для mixed array [1, true]
enum MixedValue: Codable {
    case int(Int)
    case bool(Bool)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.typeMismatch(
                MixedValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or Bool"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

// Модель данных, соответствующая оригинальной структуре
struct JsonGenerateCoordinate: Codable {
    let x: Double
    let y: Double
    let z: Double
    let name: String
    let opts: [String: [MixedValue]]
    
    // Инициализатор для удобства
    init(x: Float, y: Float, z: Float, name: String) {
        self.x = Double(x)
        self.y = Double(y)
        self.z = Double(z)
        self.name = name
        self.opts = ["1": [.int(1), .bool(true)]]
    }
}

struct JsonGenerateData: Codable {
    let coordinates: [JsonGenerateCoordinate]
    let info: String
}

final class JsonGenerate: BenchmarkProtocol {
    var n: Int = 0
    private var data: [[String: Any]] = []
    private var text: String = ""
    
    init() {
        n = iterations
    }
    
    func prepare() {
        data = (0..<n).map { _ in
            // ТОЧНО как в оригинале, даже если медленно
            let xStr = String(format: "%.8f", Helper.nextFloat())
            let yStr = String(format: "%.8f", Helper.nextFloat())
            let zStr = String(format: "%.8f", Helper.nextFloat())
            let nameStr = String(format: "%.7f", Helper.nextFloat())
            let randomInt = Helper.nextInt(max: 10000)
            
            return [
                "x": Double(xStr)!,  // String -> Double
                "y": Double(yStr)!,
                "z": Double(zStr)!,
                "name": "\(nameStr) \(randomInt)",  // ТОЧНО как в оригинале
                "opts": ["1": [1, true]] as [String: Any]
            ] as [String: Any]
        }
    }
    
    func run() {
        // ТОЧНО как в оригинале
        let jsonArray = data.map { $0 }  // Лишний map, но так в оригинале
        let jsonObject: [String: Any] = [
            "coordinates": jsonArray,
            "info": "some info"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            text = jsonString
        }
    }
    
    var result: Int64 {
        return 1
    }
}