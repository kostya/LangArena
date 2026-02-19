import Foundation

final class JsonParseDom: BenchmarkProtocol {
  private var text: String = ""
  private var resultVal: UInt32 = 0

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

  private func calcDom(_ text: String) -> (Double, Double, Double) {
    guard let data = text.data(using: .utf8) else {
      return (0, 0, 0)
    }
    do {
      let json = try JSONSerialization.jsonObject(with: data)
      guard let dict = json as? [String: Any],
        let coordinates = dict["coordinates"] as? [[String: Any]]
      else {
        return (0, 0, 0)
      }
      var x = 0.0
      var y = 0.0
      var z = 0.0

      for coord in coordinates {
        let coordX = coord["x"] as? Double ?? 0
        let coordY = coord["y"] as? Double ?? 0
        let coordZ = coord["z"] as? Double ?? 0
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

  func run(iterationId: Int) {
    let (x, y, z) = calcDom(text)
    resultVal &+= Helper.checksumF64(x) &+ Helper.checksumF64(y) &+ Helper.checksumF64(z)
  }

  var checksum: UInt32 {
    return resultVal
  }
}
