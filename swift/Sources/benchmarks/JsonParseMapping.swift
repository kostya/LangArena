import Foundation

struct CoordinateData: Codable {
  let x: Double
  let y: Double
  let z: Double
}

struct CoordinatesData: Codable {
  let coordinates: [CoordinateData]
}

final class JsonParseMapping: BenchmarkProtocol {
  private var text: String = ""
  private var resultVal: UInt32 = 0

  init() {

  }

  func prepare() {
    let generator = JsonGenerate()
    generator.n = configValue("coords") ?? 0
    generator.prepare()
    generator.run(iterationId: 0)

    let mirror = Mirror(reflecting: generator)
    for child in mirror.children {
      if child.label == "text" {
        text = child.value as? String ?? ""
        break
      }
    }
  }

  private func calcMapping() -> (Double, Double, Double) {
    guard let data = text.data(using: .utf8) else {
      return (0, 0, 0)
    }

    do {
      let decoded = try JSONDecoder().decode(CoordinatesData.self, from: data)
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

  func run(iterationId: Int) {
    let (x, y, z) = calcMapping()
    resultVal &+= Helper.checksumF64(x) &+ Helper.checksumF64(y) &+ Helper.checksumF64(z)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func name() -> String {
    return "Json::ParseMapping"
  }
}
