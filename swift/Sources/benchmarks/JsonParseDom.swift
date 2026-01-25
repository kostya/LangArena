import Foundation
final class JsonParseDom: BenchmarkProtocol {
    private var text: String = ""
    private var _result: UInt32 = 0
    func prepare() {
        // Генерируем JSON через JsonGenerate
        let generator = JsonGenerate()
        generator.n = iterations
        generator.prepare()
        generator.run()
        // Получаем сгенерированный JSON текст
        let mirror = Mirror(reflecting: generator)
        for child in mirror.children {
            if child.label == "text" {
                text = child.value as? String ?? ""
                break
            }
        }
    }
    // DOM parsing - парсим ВСЮ структуру JSON
    private func calcDom(_ text: String) -> (Double, Double, Double) {
        guard let data = text.data(using: .utf8) else {
            return (0, 0, 0)
        }
        do {
            // DOM подход: парсим весь JSON в иерархию объектов
            let json = try JSONSerialization.jsonObject(with: data)
            guard let dict = json as? [String: Any],
                  let coordinates = dict["coordinates"] as? [[String: Any]] else {
                return (0, 0, 0)
            }
            var x = 0.0
            var y = 0.0
            var z = 0.0
            // Обрабатываем ВСЕ поля каждого объекта
            for coord in coordinates {
                // DOM: доступ ко всем полям через словарь
                let coordX = coord["x"] as? Double ?? 0
                let coordY = coord["y"] as? Double ?? 0
                let coordZ = coord["z"] as? Double ?? 0
                let _ = coord["name"] as? String ?? "" // DOM: читаем но не используем
                let _ = coord["opts"] as? [String: Any] // DOM: читаем но не используем
                x += coordX
                y += coordY
                z += coordZ
            }
            let len = Double(coordinates.count)
            return (x / len, y / len, z / len)
        } catch {
            return (0, 0, 0)
        }
    }
    func run() {
        let (x, y, z) = calcDom(text)
        let xStr = String(format: "%.7f", x)
        let yStr = String(format: "%.7f", y)
        let zStr = String(format: "%.7f", z)
        _result = Helper.checksum(xStr) &+
                 Helper.checksum(yStr) &+
                 Helper.checksum(zStr)
    }
    var result: Int64 {
        return Int64(_result)
    }
}