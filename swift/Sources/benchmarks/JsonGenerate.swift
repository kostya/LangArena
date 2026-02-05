import Foundation

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

struct JsonGenerateCoordinate: Codable {
    let x: Double
    let y: Double
    let z: Double
    let name: String
    let opts: [String: [MixedValue]]

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
    public var n: Int64 = 0
    private var data: [[String: Any]] = []
    private var text: String = ""
    private var resultVal: UInt32 = 0

    init() {
        n = configValue("coords") ?? 0
        data.reserveCapacity(Int(n))
    }

    private func customRound(_ value: Double, _ decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return round(value * factor) / factor
    }

    func prepare() {
        data.removeAll()
        for _ in 0..<Int(n) {
            let x = customRound(Double(Helper.nextFloat()), 8)
            let y = customRound(Double(Helper.nextFloat()), 8)
            let z = customRound(Double(Helper.nextFloat()), 8)
            let name = String(format: "%.7f", Helper.nextFloat()) + " " + String(Helper.nextInt(max: 10000))

            data.append([
                "x": x,
                "y": y,
                "z": z,
                "name": name,
                "opts": ["1": [1, true]]
            ])
        }
    }

    func run(iterationId: Int) {
        let jsonArray = data.map { $0 }
        let jsonObject: [String: Any] = [
            "info": "some info",
            "coordinates": jsonArray
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            text = jsonString
            if text.hasPrefix("{\"") {
                resultVal += 1
            }
        }
    }

    var checksum: UInt32 {
        return resultVal
    }
}