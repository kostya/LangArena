import Foundation

// Структуры для парсинга JSON с помощью JSONDecoder
struct CoordinateData: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct CoordinatesData: Codable {
    let coordinates: [CoordinateData]
}

final class JsonParseMapping: BenchmarkProtocol {
    // Добавляем обязательные свойства протокола
    var iterations: Int = 0
    
    private var jsonData: Data?  // Храним Data вместо String
    private var _result: UInt32 = 0
    
    // Инициализатор
    init() {
        let input = Helper.getInput("JsonParseMapping")
        self.iterations = Int(input ?? "100") ?? 100
    }
    
    func prepare() {
        // Генерируем JSON через JsonGenerate
        let generator = JsonGenerate()
        generator.n = iterations
        generator.prepare()
        generator.run()
        
        // Получаем сгенерированный JSON текст через публичный метод или рефлексию
        // Поскольку text приватный, используем Mirror (как в оригинале)
        let mirror = Mirror(reflecting: generator)
        for child in mirror.children {
            if child.label == "text" {
                if let jsonString = child.value as? String,
                   let data = jsonString.data(using: .utf8) {
                    jsonData = data
                }
                break
            }
        }
    }
    
    // Mapping parsing - используем JSONDecoder
    private func calcMapping() -> (Double, Double, Double) {
        guard let jsonData = jsonData else {
            return (0, 0, 0)
        }
        
        do {
            // Используем JSONDecoder вместо JSONSerialization
            let decoded = try JSONDecoder().decode(CoordinatesData.self, from: jsonData)
            let coordinates = decoded.coordinates
            let count = Double(coordinates.count)
            
            guard count > 0 else {
                return (0, 0, 0)
            }
            
            var x = 0.0
            var y = 0.0
            var z = 0.0
            
            for coord in coordinates {
                x += coord.x
                y += coord.y
                z += coord.z
            }
            
            return (x / count, y / count, z / count)
        } catch {
            return (0, 0, 0)
        }
    }
    
    func run() {
        let (x, y, z) = calcMapping()
        let xStr = String(format: "%.7f", x)
        let yStr = String(format: "%.7f", y)
        let zStr = String(format: "%.7f", z)
        
        _result = Helper.checksum(xStr) &+
                 Helper.checksum(yStr) &+
                 Helper.checksum(zStr)
    }
    
    // Обязательное свойство протокола
    var result: Int64 {
        return Int64(_result)
    }
}